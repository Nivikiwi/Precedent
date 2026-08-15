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
    if "body" in event:
        payload = json.loads(event["body"])
    else:
        payload = event

    warning_id = payload.get("warning_id")
    decision = payload.get("decision")          # 'dismissed' or 'fixed'
    reasoning = payload.get("reasoning")
    decided_by = payload.get("decided_by", "unknown")
    shared = bool(payload.get("shared", False))

    if not warning_id or decision not in ("dismissed", "fixed"):
        return {
            "statusCode": 400,
            "body": json.dumps({
                "error": "warning_id is required, decision must be 'dismissed' or 'fixed'"
            })
        }

    conn = get_connection()
    cur = conn.cursor()

    cur.execute(
        """
        INSERT INTO decisions (warning_id, decision, reasoning, decided_by, shared)
        VALUES (%s, %s, %s, %s, %s)
        RETURNING id
        """,
        (warning_id, decision, reasoning, decided_by, shared)
    )
    new_decision_id = cur.fetchone()[0]

    conn.commit()
    cur.close()
    conn.close()

    return {
        "statusCode": 200,
        "body": json.dumps({
            "decision_id": str(new_decision_id),
            "warning_id": warning_id,
            "decision": decision,
            "message": "Decision saved - this will now show up as a match for future similar warnings."
        })
    }
