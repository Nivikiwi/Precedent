import psycopg2
import hashlib
import math
import re
import json
import os
import urllib.request

DIM = 128
MATCH_THRESHOLD = 0.3

MCP_URL = "https://cockroachlabs.cloud/mcp"

# ---------- embedding (free, local) ----------

def embed(text):
    vec = [0.0] * DIM
    tokens = re.findall(r"[a-zA-Z0-9]+", text.lower())
    for tok in tokens:
        h = int(hashlib.md5(tok.encode()).hexdigest(), 16)
        idx = h % DIM
        vec[idx] += 1.0
    norm = math.sqrt(sum(v * v for v in vec))
    if norm > 0:
        vec = [v / norm for v in vec]
    return vec

def vec_to_pg(vec):
    return "[" + ",".join(str(v) for v in vec) + "]"

# ---------- CockroachDB direct connection (vector search) ----------

def get_connection():
    return psycopg2.connect(
        host=os.environ["DB_HOST"],
        port=26257,
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        dbname=os.environ["DB_NAME"],
        sslmode="require"
    )

# ---------- CockroachDB Managed MCP Server (cross-repo enrichment) ----------

def call_mcp(payload):
    target_id = payload.get("id")
    req = urllib.request.Request(
        MCP_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {os.environ['MCP_API_KEY']}",
            "mcp-cluster-id": os.environ["MCP_CLUSTER_ID"],
            "Accept": "application/json, text/event-stream"
        },
        method="POST"
    )
    resp = urllib.request.urlopen(req, timeout=40)
    try:
        for raw_line in resp:
            line = raw_line.decode("utf-8").strip()
            if not line.startswith("data:"):
                continue
            json_str = line[len("data:"):].strip()
            if not json_str:
                continue
            obj = json.loads(json_str)
            if target_id is None or obj.get("id") == target_id:
                return obj
    finally:
        resp.close()
    return None

def send_notification(payload):
    """Fire-and-forget for MCP notifications (no response expected)."""
    req = urllib.request.Request(
        MCP_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {os.environ['MCP_API_KEY']}",
            "mcp-cluster-id": os.environ["MCP_CLUSTER_ID"],
            "Accept": "application/json, text/event-stream"
        },
        method="POST"
    )
    try:
        resp = urllib.request.urlopen(req, timeout=10)
        resp.close()
    except Exception:
        pass

def get_cross_repo_frequency(rule_id):
    """Ask the MCP server how many repos/warnings this rule_id has ever hit."""
    safe_rule_id = rule_id.replace("'", "''")
    try:
        call_mcp({
            "jsonrpc": "2.0", "id": 1, "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "scan-warning-memory", "version": "1.0"}
            }
        })
        send_notification({
            "jsonrpc": "2.0",
            "method": "notifications/initialized",
            "params": {}
        })
        result = call_mcp({
            "jsonrpc": "2.0", "id": 2, "method": "tools/call",
            "params": {
                "name": "select_query",
                "arguments": {
                    "database": "defaultdb",
                    "query": (
                        f"SELECT count(*) AS total, count(DISTINCT repo) AS repo_count "
                        f"FROM warnings WHERE rule_id = '{safe_rule_id}'"
                    )
                }
            }
        })
        return result if result else {"error": "no response from MCP server"}
    except Exception as e:
        # MCP enrichment is a bonus signal - never let it break the core pipeline
        return {"error": str(e)}

# ---------- main handler ----------

def lambda_handler(event, context):
    if "body" in event:
        payload = json.loads(event["body"])
    else:
        payload = event

    warnings_in = payload.get("warnings", [])
    repo = payload.get("repo", "unknown")

    conn = get_connection()
    cur = conn.cursor()

    results = []

    for w in warnings_in:
        rule_id = w.get("rule_id", "")
        package = w.get("package")
        file_path = w.get("file_path")
        description = w.get("description", "")
        severity = w.get("severity")

        text = f"{rule_id} {package or ''} {description}"
        vec = embed(text)
        pgvec = vec_to_pg(vec)

        cur.execute(
            """
            INSERT INTO warnings (rule_id, package, file_path, description, severity, repo, embedding)
            VALUES (%s, %s, %s, %s, %s, %s, %s::VECTOR)
            RETURNING id
            """,
            (rule_id, package, file_path, description, severity, repo, pgvec)
        )
        new_id = cur.fetchone()[0]
        conn.commit()  # release the write lock immediately so MCP's read isn't blocked

        cur.execute(
            """
            SELECT w2.repo, w2.rule_id, w2.description, d.decision, d.reasoning,
                   w2.org, d.shared,
                   (%s::VECTOR) <-> w2.embedding AS distance
            FROM warnings w2
            JOIN decisions d ON d.warning_id = w2.id
            WHERE w2.id != %s
              AND (w2.org = 'your-org' OR d.shared = true)
            ORDER BY distance
            LIMIT 3
            """,
            (pgvec, new_id)
        )
        matches = cur.fetchall()

        similar_warnings = []
        for m in matches:
            repo, m_rule_id, m_desc, decision, reasoning, org, shared, distance = m
            is_own_org = (org == "your-org")
            similar_warnings.append({
                "repo": repo if is_own_org else "another organization (shared precedent)",
                "rule_id": m_rule_id,
                "description": m_desc,
                "decision": decision,
                "reasoning": reasoning,
                "distance": float(distance),
                "source": "your_team" if is_own_org else "shared_community"
            })

        if similar_warnings and similar_warnings[0]["distance"] < MATCH_THRESHOLD:
            best = similar_warnings[0]
            recommendation = (
                f"Closely matches a warning in {best['repo']} that was {best['decision']}. "
                f"Reasoning: \"{best['reasoning']}\". Recommend: {best['decision']}."
            )
        else:
            recommendation = "No strong match found in history - recommend manual review."

        cross_repo_context = get_cross_repo_frequency(rule_id)

        results.append({
            "warning_id": str(new_id),
            "rule_id": rule_id,
            "description": description,
            "similar_warnings": similar_warnings,
            "recommendation": recommendation,
            "cross_repo_context": cross_repo_context
        })

    conn.commit()
    cur.close()
    conn.close()

    return {
        "statusCode": 200,
        "body": json.dumps({"results": results})
    }
