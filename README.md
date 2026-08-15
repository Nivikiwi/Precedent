# Precedent

**Every scan warning, judged by what's already been decided.**

Precedent is an agentic security-triage tool: when a developer's scanner
flags a new warning, Precedent checks whether anything like it has been
seen before — in your own repos, or (optionally) across other
organizations — and surfaces the prior decision and reasoning instead of
making the developer investigate from scratch. Every Accept/Override
becomes new memory for the next match.

Built for the CockroachDB x AWS Agentic Hackathon (2026).

- **Live app:** `<your S3 static website URL here>`
- **Demo video:** `<YouTube/Vimeo link here>`

---

## The problem

Security triage is repetitive in a very specific, well-documented way:
analysts and developers re-investigate the same false positives over and
over because the reasoning behind a past dismissal is never captured
anywhere searchable. See `docs/problem_sources.md` for the specific
GitHub issues, blog posts, and postmortems this project is grounded in.

## How it works

1. **Scan** — a scanner's JSON output (any tool, any format) is POSTed to
   the ingest endpoint.
2. **Match** — each warning is embedded and matched via CockroachDB's
   Distributed Vector Index against every past warning your org (and,
   optionally, other participating orgs) has already decided on.
3. **Recommend** — the closest match's decision and reasoning are
   surfaced, plus a cross-repo frequency count fetched live through the
   CockroachDB Cloud Managed MCP Server.
4. **Decide** — the developer accepts or overrides the recommendation.
   That decision is written back immediately and becomes precedent for
   the next match, anywhere.

## Architecture

![Architecture diagram](docs/architecture_diagram.jpg)

- **CockroachDB Serverless** (`ap-south-1`) — the persistent memory
  layer. Two tables, `warnings` and `decisions`, with a
  `VECTOR(128)` embedding column and a Distributed Vector Index for
  similarity search.
- **CockroachDB Cloud Managed MCP Server** — used at runtime by the
  ingest Lambda to run an audited, read-only cross-repo frequency query
  via a service-account-authenticated JSON-RPC call, independent of the
  app's own direct database connection.
- **AWS Lambda** (3 functions, Python 3.12) — `ingest`, `decide`,
  `history`, each exposed via a public Function URL:
  - `lambdas/ingest` — embeds new warnings, runs the vector search,
    calls the MCP server, returns recommendations.
  - `lambdas/decide` — writes Accept/Override decisions back to
    CockroachDB, including the optional cross-org `shared` flag.
  - `lambdas/history` — returns the full chronological decision
    history for a given rule/CVE (the audit-trail feature).
  - `lambdas/embed_backfill` — a maintenance function that computes
    embeddings for any row inserted directly via SQL (e.g. seed data)
    rather than through the ingest endpoint.
- **Amazon S3** — hosts `frontend/index.html`, a single-file static
  web app (React via CDN, no build step), as the live product.

No paid LLM APIs are used anywhere in this pipeline — embeddings are
computed with a free, local, zero-dependency hashing-based vectorizer
(see `lambdas/ingest/lambda_function.py`), keeping the whole project
runnable at effectively $0.

## Repository layout

```
precedent-repo/
├── lambdas/
│   ├── ingest/lambda_function.py        # embed + vector search + MCP enrichment
│   ├── decide/lambda_function.py        # write-back Accept/Override decisions
│   ├── history/lambda_function.py       # audit trail for a rule_id
│   └── embed_backfill/lambda_function.py# maintenance: backfill missing embeddings
├── db/
│   ├── 01_schema_and_seed.sql           # tables + initial seed data
│   ├── 02_shared_precedent_migration.sql# adds org/shared columns + cross-org seed
│   └── 03_expanded_seed_data.sql        # additional realistic seed history
├── frontend/
│   └── index.html                       # the live UI, single static file
└── docs/
    ├── architecture_diagram.jpg
    └── problem_sources.md
```

## Setup — deploying your own instance

### 1. CockroachDB

1. Create a free CockroachDB Serverless cluster (any cloud region).
2. Run `db/01_schema_and_seed.sql`, then `db/02_shared_precedent_migration.sql`,
   then `db/03_expanded_seed_data.sql`, in order, in the CockroachDB SQL shell.
3. In the cluster's **Connect** page, note your connection details
   (host, user, password, database — normally `defaultdb`).
4. Enable the **Managed MCP Server** for the cluster and create a
   **service account** with an API key scoped to this cluster (needs
   SQL query permission — the "Cluster Admin" role is the safe default
   for a low-stakes demo cluster; scope it down for production use).

### 2. AWS Lambda (x4 functions)

For each function in `lambdas/`:

1. Create a new Lambda function, Python 3.12 runtime.
2. Attach a `psycopg2-binary` layer for your runtime/region — a public
   prebuilt one is available via [Klayers](https://api.klayers.cloud/api/v2/p3.12/layers/latest/).
3. Paste in the corresponding `lambda_function.py`.
4. Set environment variables:
   - `DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` (all four functions)
   - `MCP_API_KEY`, `MCP_CLUSTER_ID` (`ingest` function only, for the MCP enrichment step)
5. Enable a **Function URL** with auth type `NONE` and CORS wildcarded
   (`*` for origin/headers/methods) for `ingest`, `decide`, and
   `history` (the `embed_backfill` function only needs to be invoked
   manually/on a schedule, no public URL required).
6. Set the timeout to at least 30-60 seconds on `ingest` (it makes an
   external MCP call per warning).

### 3. Frontend

1. Open `frontend/index.html` and replace the `INGEST_URL`,
   `DECIDE_URL`, and `HISTORY_URL` constants near the top with your own
   three Function URLs from the step above.
2. Create an S3 bucket, enable **static website hosting** with
   `index.html` as the index document, disable "Block all public
   access," and attach a public-read bucket policy.
3. Upload `index.html`. Your site is now live at the bucket's website
   endpoint.

### 4. Backfill embeddings for the seed data

The SQL seed files insert warnings without embeddings (embeddings are
computed in application code, not SQL). After running the DB setup,
manually invoke `embed_backfill` once (empty `{}` test event) to embed
every seeded row before using the app.

## CockroachDB tools used

- **Distributed Vector Indexing** — the core matching mechanism; every
  recommendation the agent makes is driven by a live `VECTOR(128)`
  similarity search.
- **Cloud Managed MCP Server** — used live, on every ingest call, for
  an independent, audited, read-only cross-repo frequency lookup —
  a genuinely separate code path from the app's direct database
  connection, authenticated via a scoped service account.

## AWS services used

- **AWS Lambda** — runs the entire application logic, serverless.
- **Amazon S3** — hosts the live static frontend.

## License

MIT — see `LICENSE`.
