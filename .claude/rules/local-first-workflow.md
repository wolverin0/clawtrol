# Local-First Immutable Release Workflow
<!-- Covers local development and exact-SHA image delivery to the private-LAN ClawTrol VM. -->
<!-- Key terms: canonical clone, tested SHA, immutable image, host runtime env, health revision. -->
<!-- Read before editing deployment files, building a release, migrating, or operating the VM. -->
<!-- Source is edited locally; production runs a registry image tagged only by the tested Git SHA. -->
<!-- The VM never builds or pulls application source during a normal deployment. -->
<!-- Updated: 2026-07-26 safe-LAN revival remediation. -->

## Golden rule

Edit and test in the canonical local clone. Release through
`/deploy-to-vm`, which deploys the exact SHA-tagged image produced by green
hosted CI. Never edit source, build an image, or pull a branch on the VM.

## Topology

- Local clone: source edits, tests, and atomic commits.
- GitHub: canonical Git history and fail-closed CI.
- GitHub Container Registry: `ghcr.io/wolverin0/clawtrol:<40-char-sha>`.
- VM deployment directory: non-secret Compose descriptor and release pointer.
- VM runtime environment: access-restricted, host-side secrets and database URL.
- Production: one ClawTrol web container, no ClawTrol worker or Compose database.

## Daily flow

1. Create a dedicated branch/worktree from the canonical clone.
2. Make a small change and run the touched-area tests and security checks.
3. Commit and push the exact revision.
4. Require hosted CI to pass for that exact revision.
5. For schema changes, validate the exact image against an isolated restored
   production dump and preserve the evidence.
6. Invoke `/deploy-to-vm <40-character-sha>`.
7. Require `/health` to report the same SHA and all runtime checks green.

## Prohibited deployment patterns

- Pulling a branch into a VM checkout and restarting an existing container.
- Running `docker compose build` on the VM.
- Deploying `latest`, a branch name, or any mutable image tag.
- Running `db:prepare`, destructive migrations, or migrations at container boot.
- Starting the retired systemd units or a Solid Queue worker.
- Copying runtime secrets into Git, release descriptors, terminal output, or chat.
- Calling `/up` or Docker health alone sufficient release evidence.

## Allowed SSH use

SSH is for bounded deployment operations and read-only diagnostics: inspect
container state, tail logs, verify stopped units, and run an explicitly approved
one-off migration from the exact release image. Do not open an editor in a VM
source checkout.

## Recovery

Rollback selects the previous immutable image and recreates the single web
container. Stop the passive mirror and revoke its token first. Restore a
database dump only if integrity requires it. Never restore revoked credentials
or legacy execution.
