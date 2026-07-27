---
name: deploy-to-vm
description: Deploy an already-tested, exact-SHA ClawTrol image to the private-LAN VM without pulling or building source on the host.
argument-hint: "<40-character-tested-sha>"
trigger: /deploy-to-vm
---

# deploy-to-vm

Deploy one immutable web image to the private-LAN VM. This skill never builds
on the host, pulls source into a VM checkout, starts a worker, or deploys a
floating tag.

## Required input and host state

- `REVISION`: the exact 40-character lowercase Git SHA that passed hosted CI.
- Image: `ghcr.io/wolverin0/clawtrol:${REVISION}`.
- Local repository: clean and checked out at `REVISION`.
- Host deployment directory: `$HOME/.local/share/clawtrol-deploy`.
- Host secret environment: `$HOME/.config/clawtrol/runtime.env`, mode `0600`.
- Restored-database migration evidence for this exact image revision.
- Both retired systemd web units and the Solid Queue worker remain stopped.

Never print, copy into the repository, or place the host runtime environment in
command arguments. Docker Compose reads it from the host-side environment file.

## Hard preflight

Run locally and stop on any failure:

```bash
test "$(git rev-parse HEAD)" = "$REVISION"
test -z "$(git status --porcelain)"
test "$(git rev-parse "$REVISION^{commit}")" = "$REVISION"
git fetch origin
git merge-base --is-ancestor "$REVISION" origin/main
gh run list --commit "$REVISION" --workflow CI --json conclusion,headSha \
  --jq 'any(.[]; .headSha == "'"$REVISION"'" and .conclusion == "success")'
```

Confirm the migration artifact was produced by
`bash script/verify_restored_migrations.sh` against an isolated restore of the active
database. A schema-only or empty-database migration pass is not sufficient.

Run read-only host checks:

```bash
ssh -o BatchMode=yes -o ConnectTimeout=8 "$CLAWTROL_VM" 'set -eu
test -f "$HOME/.config/clawtrol/runtime.env"
test "$(stat -c %a "$HOME/.config/clawtrol/runtime.env")" = 600
for unit in clawdeck-web.service clawtrol.service clawtrol-worker.service; do
  ! systemctl --user is-active --quiet "$unit"
done'
```

If the runtime environment is absent, permissions are broader than `0600`, a
retired unit is active, CI is not green for the exact SHA, or restore evidence
is missing, stop. Do not repair host secrets or start/stop services implicitly.

## Stage the immutable release

Copy only the Compose descriptor from the tested checkout:

```bash
ssh "$CLAWTROL_VM" 'mkdir -p "$HOME/.local/share/clawtrol-deploy"'
scp docker-compose.yml \
  "$CLAWTROL_VM:~/.local/share/clawtrol-deploy/docker-compose.yml.next"
ssh "$CLAWTROL_VM" "set -eu
cd \"\$HOME/.local/share/clawtrol-deploy\"
printf 'CLAWTROL_IMAGE=ghcr.io/wolverin0/clawtrol:%s\n' '$REVISION' > release.env.next
chmod 600 release.env.next
docker pull 'ghcr.io/wolverin0/clawtrol:$REVISION'
test \"\$(docker image inspect 'ghcr.io/wolverin0/clawtrol:$REVISION' \
  --format '{{ index .Config.Labels \"org.opencontainers.image.revision\" }}')\" = '$REVISION'
docker compose \
  --env-file release.env.next \
  --env-file \"\$HOME/.config/clawtrol/runtime.env\" \
  -f docker-compose.yml.next config --quiet"
```

Do not continue if the image label, Compose image, or tested SHA differ.

## Production migration gate

Migrations are a separate, explicit operator-approved action. For a release
with migrations:

1. Verify the exact image against the isolated restored database.
2. Confirm only expand-phase changes are present.
3. Preserve the active database dump and verified row counts.
4. Obtain explicit approval for the production migration.
5. Run `db:migrate` once from the exact SHA image with the host runtime env.

Never use `db:prepare`, `db:reset`, or a boot-time migration. Contract/drop
migrations wait until the compatibility soak and a separate release.

## Cut over one web container

Back up the previous non-secret release descriptor, atomically activate the new
descriptor, and recreate only the web service:

```bash
ssh "$CLAWTROL_VM" "set -eu
cd \"\$HOME/.local/share/clawtrol-deploy\"
test ! -f release.env || cp release.env release.env.previous
test ! -f docker-compose.yml || cp docker-compose.yml docker-compose.yml.previous
mv release.env.next release.env
mv docker-compose.yml.next docker-compose.yml
docker compose \
  --env-file release.env \
  --env-file \"\$HOME/.config/clawtrol/runtime.env\" \
  pull clawdeck
docker compose \
  --env-file release.env \
  --env-file \"\$HOME/.config/clawtrol/runtime.env\" \
  up -d --no-build --no-deps clawdeck"
```

Do not run `docker compose up` without a service name. The revived topology is
one ClawTrol web container and no Compose database or worker.

## Release proof

Poll for at most 60 seconds, then require all of these:

```bash
curl --fail --silent http://192.168.100.186:4001/up >/dev/null
test "$(curl --fail --silent http://192.168.100.186:4001/health |
  ruby -rjson -e 'puts JSON.parse(STDIN.read).fetch("revision")')" = "$REVISION"
```

Also verify:

- `/health` reports `status: ok`, not only Docker `healthy`.
- Login, board 5, and task history smoke checks pass.
- Compose lists exactly the `clawdeck` service.
- One Puma process exists and no Solid Queue worker exists.
- The three retired systemd units remain inactive.
- The active-database counts still match the pre-deploy anchor.

Report tested SHA, image digest, deployed revision, health status, database
counts, process evidence, and any gate that did not pass.

## Rollback

Stop the passive mirror first and revoke its token if it was enabled. Restore
the previous release descriptor and recreate the web container from the
previous immutable image. Restore the database dump only when schema or data
integrity requires it. Never roll back credential rotation or re-enable a
legacy executor.

## This skill never does

- Force-push, deploy a floating tag, or build on the VM.
- Pull application source as a deployment mechanism.
- Start systemd services, Solid Queue, Factory, Nightshift, or legacy workers.
- Auto-run migrations or use `db:prepare`.
- Print or transfer runtime credentials.
- Treat `/up`, Docker health, or a mutable restart as release proof.
