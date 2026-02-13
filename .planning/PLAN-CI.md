# CI/CD Setup Plan

## Goal
Add GitHub Actions CI to all projects that don't have it.

## Already have CI (skip): 
- elbraserito, pedrito, douglas-haig, whatsappbot-final, clawdeck

## Need CI (8 repos):

### Vite projects (build check + test if available):
1. **argentina-sales-hub** — `/mnt/pyapps/argentina-sales-hub` — vite, NO test script
2. **fitflow-pro-connect2** — `/mnt/pyapps/fitflow-pro-connect2` — vite, NO test script
3. **goodmorning** — `/mnt/pyapps/goodmorning` — vite, HAS test script
4. **nereidas** — `/mnt/pyapps/nereidas` — vite, HAS test script
5. **mutual** — `/mnt/pyapps/mutual` — vite, NO test script

### Next.js projects:
6. **gimnasio-next** — `/mnt/pyapps/gimnasio/gimnasio-next` — next, HAS test script
7. **personaldashboard** — `/mnt/pyapps/personaldashboard` — next, HAS test script

### Other:
8. **newspage** — `/mnt/pyapps/newspage` — check stack, HAS test? TBD
9. **final-inpla** — `/mnt/pyapps/final-inpla` — check stack

## CI Template (Vite, no tests):
```yaml
name: CI
on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npm run build
```

## CI Template (Vite/Next, with tests):
Same as above plus:
```yaml
      - run: npm test
```

## Workflow:
For each project:
1. Create `.github/workflows/ci.yml`
2. Git add, commit "ci: add GitHub Actions workflow"
3. Push

## Verify:
- Check GitHub Actions tab shows green for each repo
