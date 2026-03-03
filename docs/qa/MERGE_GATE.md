# Merge Gate

`bin/merge_gate` enforces a hard validation gate before integration.

## Usage

```bash
bin/merge_gate --profile quick
bin/merge_gate --profile full
bin/merge_gate --profile full --output docs/artifacts/manual-merge-gate.md
```

## Profiles

- `quick`
  - `bin/rubocop`
  - `bin/brakeman -q`
  - `bin/bundler-audit check`
  - `bin/rails test`
  - `bin/rails zeitwerk:check`

- `full`
  - all `quick` steps
  - `bin/rails test:system`

Any failed step returns non-zero exit code.

## Artifacts

For each run, the script writes:
- Markdown report: `docs/artifacts/<timestamp>-merge-gate-<profile>.md`
- Raw log: same filename with `.log`

## Factory Integration

`CherryPickService.verify_production!` now calls `bin/merge_gate`.

Default profile is `quick`; override with:

```bash
MERGE_GATE_PROFILE=full
```
