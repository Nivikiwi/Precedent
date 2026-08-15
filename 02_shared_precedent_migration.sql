-- Run these one at a time in the CockroachDB SQL shell.

-- 1. Add the two new columns
ALTER TABLE warnings ADD COLUMN IF NOT EXISTS org STRING DEFAULT 'your-org';
ALTER TABLE decisions ADD COLUMN IF NOT EXISTS shared BOOL DEFAULT false;

-- 2. Seed a fictional second org's warnings + shared decisions.
--    repo is intentionally generic ("member-org") and decided_by is null,
--    simulating the anonymization that happens before something enters the shared pool.

INSERT INTO warnings (id, rule_id, package, file_path, description, severity, repo, org) VALUES
    ('00000000-0000-0000-0000-000000000101', 'CVE-2019-10744', 'lodash', 'package-lock.json',
     'Prototype pollution in lodash via defaultsDeep function', 'high', 'member-org', 'acme-corp'),
    ('00000000-0000-0000-0000-000000000102', 'CVE-2022-25883', 'semver', 'package-lock.json',
     'ReDoS in semver via crafted version string in range parsing', 'medium', 'member-org', 'acme-corp'),
    ('00000000-0000-0000-0000-000000000103', 'CVE-2021-23337', 'lodash', 'package-lock.json',
     'Command injection in lodash via template function', 'high', 'member-org', 'globex-inc');

INSERT INTO decisions (warning_id, decision, reasoning, decided_by, shared) VALUES
    ('00000000-0000-0000-0000-000000000101', 'dismissed',
     'defaultsDeep is only called with hardcoded internal config objects, never user input.', NULL, true),
    ('00000000-0000-0000-0000-000000000102', 'dismissed',
     'Version strings come from our own build pipeline, never external/user-supplied input.', NULL, true),
    ('00000000-0000-0000-0000-000000000103', 'fixed',
     'Upgraded lodash to 4.17.21 which patches the template injection path.', NULL, true);

-- 3. Sanity check
SELECT w.org, w.rule_id, d.decision, d.shared, d.reasoning
FROM warnings w
JOIN decisions d ON d.warning_id = w.id
WHERE w.org != 'your-org'
ORDER BY w.rule_id;
