-- ============================================================
-- Day 1: Schema + seed data for "Dismissal Memory" MVP
-- Run this against your CockroachDB Cloud Serverless cluster.
-- ============================================================

-- 1. Tables
CREATE TABLE IF NOT EXISTS warnings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id STRING NOT NULL,
    package STRING,
    file_path STRING,
    description STRING NOT NULL,
    severity STRING,
    repo STRING,
    org STRING DEFAULT 'your-org',    -- lets us simulate/support multiple orgs sharing precedent
    embedding VECTOR(128),            -- filled in on Day 3 via free hashing-vectorizer (no paid API)
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS decisions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    warning_id UUID NOT NULL REFERENCES warnings(id),
    decision STRING NOT NULL,        -- 'dismissed' or 'fixed'
    reasoning STRING,
    decided_by STRING,
    shared BOOL DEFAULT false,       -- true = anonymized and visible cross-org
    decided_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Vector index (leave commented out until Day 3, once embeddings exist —
--    some CockroachDB versions want non-null vectors before indexing).
-- CREATE VECTOR INDEX IF NOT EXISTS warnings_embedding_idx ON warnings (embedding);

-- 3. Seed data: past warnings across two fake repos, with decisions.
--    embedding is left NULL here on purpose — Day 3's script fills it in.

INSERT INTO warnings (id, rule_id, package, file_path, description, severity, repo) VALUES
    ('00000000-0000-0000-0000-000000000001', 'CVE-2015-5237', 'google.golang.org/protobuf', 'go.sum',
     'Denial of service in protobuf C++ parsing via malformed message', 'high', 'billing-service'),

    ('00000000-0000-0000-0000-000000000002', 'CVE-2023-45857', 'axios', 'package-lock.json',
     'Axios exposes confidential data to unintended third party via redirect', 'medium', 'billing-service'),

    ('00000000-0000-0000-0000-000000000003', 'CVE-2021-44228', 'log4j-core', 'pom.xml',
     'Remote code execution via JNDI lookup in log message', 'critical', 'billing-service'),

    ('00000000-0000-0000-0000-000000000004', 'CVE-2020-8203', 'lodash', 'package-lock.json',
     'Prototype pollution in lodash via zipObjectDeep', 'medium', 'auth-service'),

    ('00000000-0000-0000-0000-000000000005', 'CVE-2015-5237', 'google.golang.org/protobuf', 'go.sum',
     'Denial of service in protobuf C++ parsing via malformed message', 'high', 'auth-service'),

    ('00000000-0000-0000-0000-000000000006', 'CVE-2022-3517', 'minimatch', 'package-lock.json',
     'ReDoS in minimatch via crafted pattern', 'medium', 'auth-service'),

    ('00000000-0000-0000-0000-000000000007', 'CVE-2023-45857', 'axios', 'package-lock.json',
     'Axios exposes confidential data to unintended third party via redirect', 'medium', 'notifications-service'),

    ('00000000-0000-0000-0000-000000000008', 'CVE-2021-44228', 'log4j-core', 'pom.xml',
     'Remote code execution via JNDI lookup in log message', 'critical', 'notifications-service');

INSERT INTO decisions (warning_id, decision, reasoning, decided_by) VALUES
    ('00000000-0000-0000-0000-000000000001', 'dismissed',
     'We only use the Go package, this CVE is for the C++ implementation - not reachable.', 'alex'),

    ('00000000-0000-0000-0000-000000000002', 'fixed',
     'Upgraded axios to 1.6.7 which patches the redirect issue.', 'priya'),

    ('00000000-0000-0000-0000-000000000003', 'fixed',
     'Upgraded log4j-core to 2.17.1 immediately, this is exploitable.', 'priya'),

    ('00000000-0000-0000-0000-000000000004', 'dismissed',
     'zipObjectDeep is never called with user-controlled keys in our codebase.', 'sam'),

    ('00000000-0000-0000-0000-000000000006', 'dismissed',
     'Pattern is developer-authored config, not user input - no ReDoS path.', 'sam'),

    ('00000000-0000-0000-0000-000000000008', 'fixed',
     'Same log4j issue as billing-service, applied the same upgrade.', 'jordan');

-- Note: warnings 5 and 7 are intentionally left WITHOUT a decision yet -
-- they represent "new" warnings you can run through the pipeline later
-- to test that the similarity search finds warnings 1 and 2 as matches.

-- 4. Sanity check queries - run these after the inserts to confirm everything landed.
SELECT count(*) AS warning_count FROM warnings;
SELECT count(*) AS decision_count FROM decisions;

SELECT w.repo, w.rule_id, w.severity, d.decision, d.reasoning
FROM warnings w
LEFT JOIN decisions d ON d.warning_id = w.id
ORDER BY w.repo, w.rule_id;
