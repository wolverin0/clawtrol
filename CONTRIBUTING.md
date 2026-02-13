# Contributing to ClawDeck

Thank you for your interest in contributing to ClawDeck! 🦞

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/clawdeck.git`
3. Create a branch: `git checkout -b feature/your-feature`
4. Make your changes
5. Run tests: `bin/ci`
6. Commit with a clear message
7. Push and open a Pull Request

## Development Setup

```bash
bundle install
bin/rails db:prepare
bin/dev
```

## Conventional Commits

This project enforces [Conventional Commits](https://www.conventionalcommits.org/). A `commit-msg` git hook validates your messages automatically.

**Format:** `<type>[optional scope]: <description>`

**Types:**
| Type | Purpose |
|------|---------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `chore` | Maintenance (deps, config) |
| `refactor` | Code change (no new feature/fix) |
| `test` | Adding/fixing tests |
| `ci` | CI/CD changes |
| `style` | Formatting, whitespace |
| `perf` | Performance improvement |
| `build` | Build system changes |

**Examples:**
```
feat: add user authentication
fix(api): handle nil task gracefully
docs: update README with setup instructions
chore(deps): bump rails to 8.0.2
refactor!: restructure task model (breaking change)
```

**Install the hook** (done automatically on clone, or manually):
```bash
ln -sf ../../bin/commit-msg-hook .git/hooks/commit-msg
```

**Generate CHANGELOG.md** from commit history:
```bash
bin/changelog
```

The changelog is also auto-generated on pushes to `main` via GitHub Actions.

## Code Style

- Follow existing code patterns
- Run `bin/rubocop` before committing
- Write tests for new features

## Pull Request Guidelines

- Keep PRs focused on a single change
- Update documentation if needed
- Add tests for new functionality
- Reference related issues in the PR description

## Reporting Issues

- Search existing issues first
- Include steps to reproduce
- Include Ruby/Rails versions
- Include relevant logs or screenshots

## Questions?

Open a Discussion or join our Discord.

---

Thank you for helping make ClawDeck better! 🦞
