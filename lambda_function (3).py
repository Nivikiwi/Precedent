"""
scan-warning-memory-embed-backfill

Computes and stores embeddings for any row in `warnings` that doesn't
have one yet. Run this once after seeding new rows directly via SQL
(the SQL INSERT statements in /db don't compute embeddings themselves).

Free, zero-dependency embedding: a 128-dimension hashing-based bag-of-words
vector. No external API calls, no cost. Good enough for near-duplicate /
paraphrase-level matching, which is the common case for repeated CVE
descriptions across repos.
"""

import hashlib
import math
import re
import json
import os
import psycopg2

DIM = 128


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


def get_connection():
    return psycopg2.connect(
        host=os.environ["DB_HOST"],
        port=26257,
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        dbname=os.environ["DB_NAME"],
        sslmode="require",
    )


def lambda_handler(event, context):
    conn = get_connection()
    cur = conn.cursor()

    cur.execute(
        "SELECT id, rule_id, package, description FROM warnings WHERE embedding IS NULL"
    )
    rows = cur.fetchall()

    updated = 0
    for wid, rule_id, package, description in rows:
        text = f"{rule_id} {package or ''} {description}"
        vec = embed(text)
        cur.execute(
            "UPDATE warnings SET embedding = %s::VECTOR WHERE id = %s",
            (vec_to_pg(vec), wid),
        )
        updated += 1

    conn.commit()
    cur.close()
    conn.close()

    return {
        "statusCode": 200,
        "body": json.dumps({"rows_updated": updated}),
    }
