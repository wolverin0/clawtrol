# ClawTrol Safe-LAN Remediation Decisions
<!-- Covers all 36 findings from audit-report.md and records REMEDIATE or DEFER only. -->
<!-- Key terms: Safe-LAN revival, passive Hermes mirror, no accepted risk, review 2026-08-31. -->
<!-- Read when implementing, reviewing, or deciding whether the revival may advance phases. -->
<!-- Active branch: remediation/safe-lan-revival-20260726 from recovery commit 9035ed8. -->
<!-- Owners: remediation branch for repository work; operator for credential, legal, and runtime gates. -->
<!-- Status: ACTIVE; deferred findings remain open and are not accepted. -->

No finding is accepted. `DEFER` means the finding stays open, is excluded from the private-LAN first milestone, and must be reviewed on 2026-08-31. A containment that removes current exploitability does not silently close the underlying deferred refactor.

## Decisions

| Finding | Decision | Rationale | Owner | Review date | Evidence / exit gate |
|---|---|---|---|---|---|
| F-1.1 | REMEDIATE | Critical credential incident and active authentication path. | Operator + remediation branch | Before R2 | Old credential returns 401; legacy hook auth retired; full-history and artifact scans clean. |
| F-1.2 | REMEDIATE | Critical same-origin untrusted HTML execution. | Remediation branch | Before R3 | Marketing, Preview, and Showcase HTML is inert; malicious fixtures cannot access cookies, parent DOM, CSRF, or authenticated APIs. |
| F-1.3 | DEFER | TLS/HSTS is a public/trusted-LAN launch gate, outside the private-LAN milestone. | Operator | 2026-08-31 | No public-ready claim; TLS termination, redirects, HSTS, and Secure-cookie proof remain required. |
| F-1.4 | REMEDIATE | Broad network safelisting weakens the application security gate. | Remediation branch | Before R4 | Only exact health/service-route exceptions remain; forwarded external traffic is throttled. |
| F-2.1 | DEFER | Controller/service decomposition is a large refactor; legacy completion execution is retired in the milestone. | Remediation branch | 2026-08-31 | Retired routes fail closed; service extraction remains an open bead. |
| F-2.2 | DEFER | Tasks API decomposition is a large refactor outside containment scope. | Remediation branch | 2026-08-31 | No scope expansion; duplicate F-9.1 linked to the shared root cause. |
| F-2.3 | DEFER | Marketing controller decomposition is Medium UX/maintainability work. | Remediation branch | 2026-08-31 | Raw HTML execution is removed separately under F-1.2. |
| F-3.1 | DEFER | Foreign-key cleanup is explicitly post-revival database work. | Remediation branch | 2026-08-31 | Migration remains open and requires restored-dump verification. |
| F-4.1 | REMEDIATE | Pull-and-restart can leave old code running. | Remediation branch | Before containment deploy | SHA-tagged image is built and deployed; `/health` revision equals the tested Git SHA. |
| F-4.2 | REMEDIATE | Hosted CI currently suppresses security-tool failures. | Remediation branch | Before containment deploy | CI fails on RuboCop, tests, Brakeman warnings/parser errors, Bundler Audit, secret scan, migrations, mirror tests, and direct-control enforcement. |
| F-4.3 | REMEDIATE | Hardcoded database administrator credentials are a low-effort path. | Remediation branch + operator | Before candidate build | Compose requires environment-provided database values and no default credential. |
| F-5.1 | REMEDIATE | Synchronous Docker execution is removed from the Safe-LAN web surface. | Remediation branch | Before R3 | ZeroBitch execution routes return 404 or 410 and no worker runs. |
| F-5.2 | DEFER | Admin N+1 work is post-revival performance work. | Remediation branch | 2026-08-31 | Performance evidence and pagination/query fix remain open. |
| F-5.3 | DEFER | Decision-queue pagination/rerender work is post-revival UX/performance work. | Remediation branch | 2026-08-31 | Bounded rendering work remains open. |
| F-6.1 | DEFER | Pointer-only controls are Medium accessibility work. | Remediation branch | 2026-08-31 | Keyboard semantics and system-browser evidence remain required. |
| F-6.2 | DEFER | Accessible naming is Medium UX work. | Remediation branch | 2026-08-31 | Accessible-name regression coverage remains required. |
| F-6.3 | DEFER | File-editor labeling is Medium UX work. | Remediation branch | 2026-08-31 | Label and assistive-technology verification remain required. |
| F-7.1 | REMEDIATE | Wake/retry duplication becomes unreachable when legacy execution is retired. | Remediation branch | Before R3 | Legacy wake routes/jobs fail closed; ordinary task APIs remain functional. |
| F-7.2 | REMEDIATE | Factory wake handling becomes unreachable when Factory is retired. | Remediation branch | Before R3 | Factory routes/jobs fail closed and cannot enqueue paid work. |
| F-7.3 | REMEDIATE | Nightshift wake ambiguity becomes unreachable when Nightshift is retired. | Remediation branch | Before R3 | Nightshift routes/jobs fail closed and recurring registrations are absent. |
| F-8.1 | DEFER | Registration legal text requires legal review and is outside private-LAN revival. | Operator + legal reviewer | 2026-08-31 | Legal approval and verified presentation remain required before broader launch. |
| F-8.2 | DEFER | Complete export/deletion is a public-launch compliance feature. | Operator + legal reviewer | 2026-08-31 | Data inventory, export, deletion, and retention behavior remain open. |
| F-8.3 | DEFER | Full retention governance requires legal/product review; recursive mirror redaction is still mandatory now. | Operator + legal reviewer | 2026-08-31 | Mirror redaction passes in R4; retention policy and webhook-wide enforcement remain open. |
| F-9.1 | DEFER | Duplicate of the oversized Tasks API boundary in F-2.2. | Remediation branch | 2026-08-31 | Linked to the shared root-cause bead; no duplicate implementation track. |
| F-9.2 | REMEDIATE | Contributor instructions must match the current project and hooks. | Remediation branch | Before R4 | Documentation names ClawTrol and only claims hooks that deterministic setup installs. |
| F-9.3 | REMEDIATE | Contradictory deployment docs directly caused deployment ambiguity. | Remediation branch | Before containment deploy | `docs/DOCS-MAP.md` marks one immutable Docker topology CURRENT and old flows SUPERSEDED. |
| F-10.1 | REMEDIATE | Image generation is paid and lacks a hard domain budget. | Remediation branch | Before R3 | Image generation is disabled by default and its endpoint cannot incur cost. |
| F-10.2 | REMEDIATE | Factory recurring paid execution is outside the revival. | Remediation branch | Before R3 | Factory scheduling and execution are unavailable. |
| F-10.3 | REMEDIATE | Fail-open budget behavior is contained by disabling every paid executor. | Remediation branch | Before R3 | No enabled Safe-LAN route/job can invoke a paid executor. |
| F-11.1 | DEFER | CSP containment is handled under F-1.2; TLS transport hardening remains deferred. | Operator + remediation branch | 2026-08-31 | Inert artifact CSP passes now; TLS/HSTS proof remains open. |
| F-11.2 | REMEDIATE | Fabricated operational health must not be exposed as real state. | Remediation branch | Before R3 | Placeholder health route is unavailable; `/health` reports only deterministic runtime data. |
| F-11.3 | REMEDIATE | The placeholder debate workflow is not a supported Safe-LAN capability. | Remediation branch | Before R3 | Debate route is unavailable and cannot create work. |
| F-12.1 | DEFER | A durable destructive-action ledger is explicitly post-revival. | Remediation branch | 2026-08-31 | Ledger design and coverage remain open; no completeness claim. |
| F-12.2 | DEFER | Incident-response/on-call process is a public-launch governance gate. | Operator | 2026-08-31 | Named escalation owner, process, and drill evidence remain required. |
| F-13.1 | REMEDIATE | Duplicate false-boundary symptom of F-1.2. | Remediation branch | Before R3 | Misleading comments and executable preview paths are removed. |
| F-13.2 | REMEDIATE | Critical preview surfaces need executable regression coverage. | Remediation branch | Before R3 | Controller/request and malicious-artifact tests execute and pass. |

## Legal-review gate: F-8.1 through F-8.3

> **LEGAL REVIEW REQUIRED — DEFERRED, NOT ACCEPTED.** ClawTrol must remain private-LAN only. No public or customer launch may rely on this document as legal approval. Privacy/terms presentation, complete export/deletion, retention, and webhook-wide data-handling policy require a qualified legal reviewer and fresh evidence by 2026-08-31.

## Phase rule

Development may resume after R1 through R3 pass. Passive Hermes integration may advance only after R4 and the full final verification gate pass. Deployment and destructive Git-history rewrite remain operator-gated actions even when repository tests are green.
