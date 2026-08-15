import psycopg2
import json
import os

def get_connection():
    return psycopg2.connect(
        host=os.environ["DB_HOST"],
        port=26257,
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        dbname=os.environ["DB_NAME"],
        sslmode="require"
    )

def lambda_handler(event, context):
    if "body" in event and event["body"]:
        payload = json.loads(event["body"])
    elif "queryStringParameters" in event and event["queryStringParameters"]:
        payload = event["queryStringParameters"]
    else:
        payload = event

    rule_id = payload.get("rule_id")
    if not rule_id:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "rule_id is required"})
        }

    conn = get_connection()
    cur = conn.cursor()

    cur.execute(
        """
        SELECT w.repo, w.rule_id, w.description, d.decision, d.reasoning, d.decided_by, d.decided_at
        FROM decisions d
        JOIN warnings w ON w.id = d.warning_id
        WHERE w.rule_id = %s
        ORDER BY d.decided_at ASC
        """,
        (rule_id,)
    )
    rows = cur.fetchall()
    cur.close()
    conn.close()

    history = [
        {
            "repo": r[0],
            "rule_id": r[1],
            "description": r[2],
            "decision": r[3],
            "reasoning": r[4],
            "decided_by": r[5],
            "decided_at": r[6].isoformat() if r[6] else None
        }
        for r in rows
    ]

    return {
        "statusCode": 200,
        "body": json.dumps({"rule_id": rule_id, "history": history})
    }
