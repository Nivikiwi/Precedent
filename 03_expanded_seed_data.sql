-- Run this whole file in the CockroachDB SQL shell.
-- Adds 15 realistic own-org warnings/decisions across 4 repos,
-- plus 4 more shared (cross-org) precedent entries for demo variety.

-- ============================================================
-- OWN-ORG WARNINGS (org defaults to 'your-org')
-- ============================================================

INSERT INTO warnings (id, rule_id, package, file_path, description, severity, repo) VALUES
    ('00000000-0000-0000-0000-000000000200', 'CVE-2021-23337', 'lodash', 'package-lock.json',
     'Command injection in lodash via template function', 'high', 'auth-service'),
    ('00000000-0000-0000-0000-000000000201', 'CVE-2020-7598', 'minimist', 'package-lock.json',
     'Prototype pollution in minimist via crafted command line argument', 'medium', 'auth-service'),
    ('00000000-0000-0000-0000-000000000202', 'CVE-2019-11358', 'jquery', 'package-lock.json',
     'Prototype pollution in jQuery via $.extend deep merge', 'medium', 'gateway-service'),
    ('00000000-0000-0000-0000-000000000203', 'CVE-2021-3807', 'ansi-regex', 'package-lock.json',
     'ReDoS in ansi-regex via crafted terminal escape sequence', 'medium', 'gateway-service'),
    ('00000000-0000-0000-0000-000000000204', 'CVE-2022-0536', 'follow-redirects', 'package-lock.json',
     'Information exposure via authorization header leaked across redirect', 'medium', 'billing-service'),
    ('00000000-0000-0000-0000-000000000205', 'CVE-2023-26136', 'tough-cookie', 'package-lock.json',
     'Prototype pollution in tough-cookie via crafted cookie property', 'medium', 'billing-service'),
    ('00000000-0000-0000-0000-000000000206', 'CVE-2020-28469', 'glob-parent', 'package-lock.json',
     'ReDoS in glob-parent via crafted glob pattern', 'low', 'checkout-service'),
    ('00000000-0000-0000-0000-000000000207', 'CVE-2022-37601', 'loader-utils', 'package-lock.json',
     'Prototype pollution in loader-utils via crafted query parameter', 'high', 'checkout-service'),
    ('00000000-0000-0000-0000-000000000208', 'CVE-2021-44906', 'minimist', 'package-lock.json',
     'Prototype pollution in minimist via __proto__ key in parsed args', 'critical', 'checkout-service'),
    ('00000000-0000-0000-0000-000000000209', 'CVE-2023-28155', 'request', 'package-lock.json',
     'Server-side request forgery via unvalidated redirect in request library', 'high', 'payments-service'),
    ('00000000-0000-0000-0000-000000000210', 'CVE-2021-3918', 'json-schema', 'package-lock.json',
     'Prototype pollution in json-schema via crafted validation input', 'medium', 'payments-service'),
    ('00000000-0000-0000-0000-000000000211', 'CVE-2020-8116', 'dot-prop', 'package-lock.json',
     'Prototype pollution in dot-prop via crafted object path', 'medium', 'payments-service'),
    ('00000000-0000-0000-0000-000000000212', 'CVE-2021-23337', 'lodash', 'package-lock.json',
     'Command injection in lodash via template function', 'high', 'gateway-service'),
    ('00000000-0000-0000-0000-000000000213', 'CVE-2020-7598', 'minimist', 'package-lock.json',
     'Prototype pollution in minimist via crafted command line argument', 'medium', 'checkout-service'),
    ('00000000-0000-0000-0000-000000000214', 'CVE-2023-28155', 'request', 'package-lock.json',
     'Server-side request forgery via unvalidated redirect in request library', 'high', 'auth-service')
ON CONFLICT (id) DO NOTHING;

INSERT INTO decisions (warning_id, decision, reasoning, decided_by) VALUES
    ('00000000-0000-0000-0000-000000000200', 'fixed',
     'Upgraded lodash to 4.17.21 across all services after the billing-service incident.', 'alex'),
    ('00000000-0000-0000-0000-000000000201', 'dismissed',
     'Args are hardcoded in our startup script, never sourced from user input.', 'sam'),
    ('00000000-0000-0000-0000-000000000202', 'fixed',
     'Upgraded jQuery to 3.5.0, patched deep merge behavior.', 'priya'),
    ('00000000-0000-0000-0000-000000000203', 'dismissed',
     'Terminal output is never rendered from untrusted strings in this service.', 'jordan'),
    ('00000000-0000-0000-0000-000000000204', 'fixed',
     'Upgraded follow-redirects to 1.15.4 which scopes headers correctly on redirect.', 'priya'),
    ('00000000-0000-0000-0000-000000000205', 'dismissed',
     'We do not parse cookies from untrusted third-party responses in this flow.', 'alex'),
    ('00000000-0000-0000-0000-000000000206', 'dismissed',
     'Glob patterns here are developer-authored build config, not user input.', 'sam'),
    ('00000000-0000-0000-0000-000000000207', 'fixed',
     'Upgraded loader-utils to 2.0.4 immediately given the severity.', 'jordan'),
    ('00000000-0000-0000-0000-000000000208', 'fixed',
     'Upgraded minimist to 1.2.6, this is a critical and easily reachable path.', 'jordan'),
    ('00000000-0000-0000-0000-000000000209', 'fixed',
     'Upgraded request usage to axios with strict redirect validation enabled.', 'priya'),
    ('00000000-0000-0000-0000-000000000210', 'dismissed',
     'Validation input in this service is always internally generated, never user-supplied.', 'alex'),
    ('00000000-0000-0000-0000-000000000211', 'dismissed',
     'Object paths are hardcoded constants in our config loader, not dynamic.', 'sam'),
    ('00000000-0000-0000-0000-000000000212', 'fixed',
     'Same lodash upgrade as billing-service and auth-service, rolled out org-wide.', 'alex'),
    ('00000000-0000-0000-0000-000000000213', 'dismissed',
     'Same reasoning as auth-service - args are hardcoded, not user-sourced.', 'sam'),
    ('00000000-0000-0000-0000-000000000214', 'fixed',
     'Same request-to-axios migration applied here as in payments-service.', 'priya');

-- ============================================================
-- MORE SHARED CROSS-ORG PRECEDENT (adds a third fictional org)
-- ============================================================

INSERT INTO warnings (id, rule_id, package, file_path, description, severity, repo, org) VALUES
    ('00000000-0000-0000-0000-000000000104', 'CVE-2020-7598', 'minimist', 'package-lock.json',
     'Prototype pollution in minimist via crafted command line argument', 'medium', 'member-org', 'initech'),
    ('00000000-0000-0000-0000-000000000105', 'CVE-2022-0536', 'follow-redirects', 'package-lock.json',
     'Information exposure via authorization header leaked across redirect', 'medium', 'member-org', 'initech'),
    ('00000000-0000-0000-0000-000000000106', 'CVE-2019-11358', 'jquery', 'package-lock.json',
     'Prototype pollution in jQuery via $.extend deep merge', 'medium', 'member-org', 'acme-corp'),
    ('00000000-0000-0000-0000-000000000107', 'CVE-2023-28155', 'request', 'package-lock.json',
     'Server-side request forgery via unvalidated redirect in request library', 'high', 'member-org', 'globex-inc')
ON CONFLICT (id) DO NOTHING;

INSERT INTO decisions (warning_id, decision, reasoning, decided_by, shared) VALUES
    ('00000000-0000-0000-0000-000000000104', 'dismissed',
     'CLI args in our deployment are generated by CI, never accept external input.', NULL, true),
    ('00000000-0000-0000-0000-000000000105', 'fixed',
     'Upgraded to follow-redirects 1.15.4 org-wide after security review.', NULL, true),
    ('00000000-0000-0000-0000-000000000106', 'fixed',
     'Upgraded jQuery to 3.5.0 across all frontend bundles.', NULL, true),
    ('00000000-0000-0000-0000-000000000107', 'fixed',
     'Migrated off the request library entirely in favor of a maintained HTTP client.', NULL, true);

-- Sanity check - should return 19 rows total (15 own-org + 4 shared)
SELECT count(*) AS new_rows_added FROM warnings WHERE id::string LIKE '00000000-0000-0000-0000-0000002%'
   OR id::string LIKE '00000000-0000-0000-0000-0000001%';
