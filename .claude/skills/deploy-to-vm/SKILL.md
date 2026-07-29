---
name: deploy-to-vm
description: Deploy an already-tested, exact-SHA ClawTrol image to the private-LAN VM without pulling or building source on the host.
argument-hint: "<40-character-tested-sha>"
trigger: /deploy-to-vm
---

# deploy-to-vm

Deploy one immutable web image to the private-LAN VM through the canonical
host control plane. This skill never builds on the host, replaces the guarded
Compose descriptor, starts a worker, or deploys a floating tag.

## Required input and host state

- `REVISION`: the exact 40-character lowercase Git SHA that passed hosted CI.
- Image: `ghcr.io/wolverin0/clawtrol:${REVISION}`.
- Local repository: clean and checked out at `REVISION`.
- Host deployment directory: `$HOME/.local/share/clawtrol-deploy`.
- Canonical host environment: `$HOME/.local/share/clawtrol-deploy/release.env`,
  mode `0600`; it contains both runtime values and `CLAWTROL_IMAGE`.
- Restored-database migration evidence for this exact image revision.
- Both retired systemd web units and the Solid Queue worker remain stopped.

The retired `$HOME/.config/clawtrol/runtime.env` must not exist and must never
be consumed. Never print or copy the canonical environment into the repository.
An image promotion may change only its `CLAWTROL_IMAGE` line.

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
deploy_dir="$HOME/.local/share/clawtrol-deploy"
test -f "$deploy_dir/docker-compose.yml"
test -f "$deploy_dir/release.env"
test "$(stat -c %a "$deploy_dir/release.env")" = 600
test ! -e "$HOME/.config/clawtrol/runtime.env"
test "$(grep -c "^CLAWTROL_IMAGE=" "$deploy_dir/release.env")" = 1
test "$(cd "$deploy_dir" && docker compose \
  --env-file release.env -f docker-compose.yml config --services)" = clawdeck
for unit in clawdeck-web.service clawtrol.service clawtrol-worker.service; do
  ! systemctl --user is-active --quiet "$unit"
done'
```

If canonical files are absent, permissions are broader than `0600`, the retired
environment still exists, the descriptor resolves to anything except the one
`clawdeck` service, a retired unit is active, CI is not green for the exact SHA,
or restore evidence is missing, stop. Do not repair host secrets, replace the
guarded descriptor, or start/stop services implicitly.

## Stage the immutable release

Pull the exact image and create a candidate environment by copying the current
canonical file and changing only its image line:

```bash
ssh "$CLAWTROL_VM" "set -eu
cd \"\$HOME/.local/share/clawtrol-deploy\"
test \"\$(grep -c '^CLAWTROL_IMAGE=' release.env)\" = 1
cp release.env release.env.next
sed -i 's|^CLAWTROL_IMAGE=.*$|CLAWTROL_IMAGE=ghcr.io/wolverin0/clawtrol:$REVISION|' \
  release.env.next
chmod 600 release.env.next
before_nonimage=\"\$(grep -v '^CLAWTROL_IMAGE=' release.env | sha256sum | cut -d' ' -f1)\"
after_nonimage=\"\$(grep -v '^CLAWTROL_IMAGE=' release.env.next | sha256sum | cut -d' ' -f1)\"
test \"\$before_nonimage\" = \"\$after_nonimage\"
docker pull 'ghcr.io/wolverin0/clawtrol:$REVISION'
test \"\$(docker image inspect 'ghcr.io/wolverin0/clawtrol:$REVISION' \
  --format '{{ index .Config.Labels \"org.opencontainers.image.revision\" }}')\" = '$REVISION'
docker compose \
  --env-file release.env.next \
  -f docker-compose.yml config --quiet
test \"\$(docker compose --env-file release.env.next \
  -f docker-compose.yml config --images)\" = \
  'ghcr.io/wolverin0/clawtrol:$REVISION'"
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

Back up the canonical environment, atomically activate the candidate, and
recreate only the web service. The guarded Compose descriptor stays untouched:

```bash
ssh "$CLAWTROL_VM" "set -eu
cd \"\$HOME/.local/share/clawtrol-deploy\"
cp release.env release.env.previous
chmod 600 release.env.previous
mv release.env.next release.env
docker compose \
  --env-file release.env \
  -f docker-compose.yml \
  pull clawdeck
docker compose \
  --env-file release.env \
  -f docker-compose.yml \
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
