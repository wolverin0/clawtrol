# ClawTrol — Backup & Restore Runbook

**Last tested:** 2026-04-18 — restore of `clawtrol_db_2026-04-17.sql.gz` matched live row counts exactly across users / tasks / boards / agent_personas / saved_links / nightshift_missions.

## Where backups live

- **Primary (on the VM):** `/home/ggorbalan/backups/clawtrol/clawtrol_db_YYYY-MM-DD.sql.gz`
- **SMB mirror:** `/mnt/pyapps/backups/clawtrol/` (copied from primary by `clawtrol-backup.sh`)
- **Google Drive mirror:** `clawtrol-backups/YYYY-MM-DD/` (rclone upload)
- **Retention:** 7 days local, managed by the backup script's rotate step.

## Backup schedule

Cron entry:
```
45 3 * * * /home/ggorbalan/.openclaw/workspace/scripts/clawtrol-backup.sh \
    >> /home/ggorbalan/backups/clawtrol/cron.log 2>&1
```

Script dumps:
1. ClawTrol Postgres DB (`clawdeck_development` on `dashboard-postgres` via user `dashboard`)
2. ClawTrol `storage/zerobitch` + `storage/soul-history` tarball
3. OpenClaw `~/.openclaw/` config tarball
4. OpenClaw `~/.openclaw/workspace/memory/` tarball
5. Telegram notification on completion.

## How to restore — verified procedure

### Prereqs

- `dashboard-postgres` container running (the real production DB host)
- `dashboard` user can `CREATE DATABASE` on that instance
- DB password in `/mnt/pyapps/personaldashboard/.env` as `DB_PASSWORD=`

### Dry-run (restore into a throwaway DB and compare row counts)

```bash
DB_PASS=$(grep '^DB_PASSWORD=' /mnt/pyapps/personaldashboard/.env | cut -d= -f2 | tr -d "'\"")
BACKUP=/home/ggorbalan/backups/clawtrol/clawtrol_db_YYYY-MM-DD.sql.gz  # pick date

# 1. Throwaway DB
PGPASSWORD=$DB_PASS psql -h 127.0.0.1 -p 5432 -U dashboard -d postgres \
  -c "CREATE DATABASE clawtrol_restore_drill OWNER dashboard;"

# 2. Restore (7 minutes for an 18 MB compressed dump)
zcat "$BACKUP" | PGPASSWORD=$DB_PASS psql -h 127.0.0.1 -p 5432 -U dashboard \
  -d clawtrol_restore_drill

# 3. Compare to live
for tbl in users tasks boards agent_personas saved_links nightshift_missions; do
  LIVE=$(PGPASSWORD=$DB_PASS psql -h 127.0.0.1 -p 5432 -U dashboard \
    -d clawdeck_development -tAc "SELECT COUNT(*) FROM $tbl")
  R=$(PGPASSWORD=$DB_PASS psql -h 127.0.0.1 -p 5432 -U dashboard \
    -d clawtrol_restore_drill -tAc "SELECT COUNT(*) FROM $tbl")
  echo "$tbl: live=$LIVE restored=$R"
done

# 4. Clean up
PGPASSWORD=$DB_PASS psql -h 127.0.0.1 -p 5432 -U dashboard -d postgres \
  -c "DROP DATABASE clawtrol_restore_drill;"
```

### Real restore (production loss scenario)

**Stop the app first** so it doesn't write into the old state:
```bash
systemctl --user stop clawtrol clawtrol-worker
```

Then either:

**Option A — restore into the current DB (destructive to current data):**
```bash
# DROP CASCADE the current DB, recreate empty
PGPASSWORD=$DB_PASS psql -h 127.0.0.1 -p 5432 -U dashboard -d postgres <<SQL
DROP DATABASE clawdeck_development WITH (FORCE);
CREATE DATABASE clawdeck_development OWNER dashboard;
SQL

zcat /home/ggorbalan/backups/clawtrol/clawtrol_db_YYYY-MM-DD.sql.gz \
  | PGPASSWORD=$DB_PASS psql -h 127.0.0.1 -p 5432 -U dashboard \
    -d clawdeck_development

systemctl --user start clawtrol clawtrol-worker
```

**Option B — restore alongside and swap (safer, zero-downtime):**
```bash
# Restore to a new DB
PGPASSWORD=$DB_PASS psql -h 127.0.0.1 -p 5432 -U dashboard -d postgres \
  -c "CREATE DATABASE clawtrol_restored OWNER dashboard;"
zcat /home/ggorbalan/backups/clawtrol/clawtrol_db_YYYY-MM-DD.sql.gz \
  | PGPASSWORD=$DB_PASS psql -h 127.0.0.1 -p 5432 -U dashboard \
    -d clawtrol_restored

# Swap names in Postgres (keeps the old one as fallback)
PGPASSWORD=$DB_PASS psql -h 127.0.0.1 -p 5432 -U dashboard -d postgres <<SQL
ALTER DATABASE clawdeck_development RENAME TO clawdeck_development_old_$(date +%s);
ALTER DATABASE clawtrol_restored RENAME TO clawdeck_development;
SQL

systemctl --user start clawtrol clawtrol-worker
```

## What the backup does NOT cover

- The `ACTIVE_RECORD_ENCRYPTION_*` keys in `/etc/clawtrol/clawtrol.env`. Losing them makes the 4 encrypted user columns (`ai_api_key`, `telegram_bot_token`, `openclaw_gateway_token`, `openclaw_hooks_token`) permanently undecryptable. **Keep a copy of those 3 env vars off-host** (password vault, encrypted file in a different backup location, etc.).
- The `SECRET_KEY_BASE`. Rotating it just invalidates active sessions; losing it means everyone has to re-login. Keep a copy the same place.
- The user's OpenClaw-side tokens in `~/.openclaw/openclaw.json`. The `clawtrol-backup.sh` does tar this up as `openclaw_config_*.tar.gz` in the same folder, so it IS backed up — just be aware restoring clawtrol alone won't bring back these tokens unless you also restore that tarball.

## Routine to schedule

**Quarterly restore drill.** Run the dry-run procedure above on the 1st of Jan / Apr / Jul / Oct. If row counts diverge, backups are silently broken — fix before it matters.
