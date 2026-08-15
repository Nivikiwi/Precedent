# Problem sources

Precedent is grounded in specific, real complaints found during research
rather than a brainstormed idea. Sources:

- **GitHub Security Lab** — "AI-supported vulnerability triage with the
  GitHub Security Lab Taskflow Agent." False-positive causes for a given
  alert type tend to be fairly similar and easy to spot once you've seen
  them before — the reasoning is repeatable, but currently isn't
  captured anywhere reusable.
  https://github.blog/security/ai-supported-vulnerability-triage-with-the-github-security-lab-taskflow-agent/

- **TheHive (open-source case management tool)** — GitHub issue #648,
  "Trigger analyzers when importing alerts as cases." A maintainer/user
  request describing that for many alert types, analysts repeat the
  exact same initial investigation steps every time, with nothing
  carried forward from prior cases.
  https://github.com/TheHive-Project/TheHive/issues/648

- **Anchore** — "False Positives and False Negatives in Vulnerability
  Scanning: Lessons from the Trenches." Documents a single
  cross-ecosystem false-positive pattern (a same-named CVE from a
  different language ecosystem) recurring 44 separate times across
  unrelated repositories.
  https://anchore.com/blog/false-positives-and-false-negatives-in-vulnerability-scanning/

- **UK Dept for Education — Secure by Design docs**, "How to triage
  vulnerabilities." Describes the real-world process most teams
  actually use: a dismissal reason is typed into a tracking tool's
  comment field, where it's effectively invisible to anyone outside
  that one repo.
  https://secure-by-design.security.education.gov.uk/Vulnerability%20Management/how_to_triage_vulnerabilities/

## Competitive context: Semgrep Memories

Semgrep ships a production feature (Memories) that does the same core
loop — turning developer triage decisions into reusable, auto-suggested
memory. It's a legitimate, more mature prior art for this idea, and we
say so explicitly rather than claiming novelty we don't have. Precedent
differs in three specific ways Semgrep's product does not offer:

1. **Scanner-agnostic** — ingests any tool's JSON output, not just one
   vendor's findings.
2. **Open, self-hostable architecture** — the entire matching and memory
   layer is inspectable and runnable on your own CockroachDB cluster,
   not a closed SaaS black box.
3. **Optional anonymized cross-org precedent sharing** — a mechanism
   Semgrep's single-tenant memory model cannot offer by design, since
   it never leaves one customer's account.

We're not claiming to out-build a funded security company in the space
of a hackathon. We're demonstrating that the underlying mechanism is
straightforward to build correctly with CockroachDB as the memory layer,
and shipping the parts (transparency, portability, shared precedent)
that remain closed everywhere else.
