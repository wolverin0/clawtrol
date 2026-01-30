# 🦞 ClawDeck

**Open source mission control for your AI agents.**

ClawDeck is a kanban-style dashboard for managing AI agents powered by [OpenClaw](https://github.com/openclaw/openclaw). Track agent status, assign tasks, and orchestrate your AI workforce from one place.

> 🚧 **Early Development** — ClawDeck is under active development. Expect breaking changes.

## Features

- **Agent Dashboard** — See all your agents and their current status
- **Kanban Tasks** — Drag-and-drop task management per agent
- **Project Boards** — Organize work into projects with agent assignments
- **Real-time Updates** — Hotwire-powered live UI updates
- **API Access** — Full REST API for agent integrations

## Tech Stack

- **Ruby** 3.3.1 / **Rails** 8.1
- **PostgreSQL** with Solid Queue, Cache, and Cable
- **Hotwire** (Turbo + Stimulus) + **Tailwind CSS**
- **Passwordless Auth** via email codes

## Quick Start

### Prerequisites
- Ruby 3.3.1
- PostgreSQL
- Bundler

### Setup
```bash
git clone https://github.com/clawdeckio/clawdeck.git
cd clawdeck
bundle install
bin/rails db:prepare
bin/dev
```

Visit `http://localhost:3000`

### Running Tests
```bash
bin/rails test              # Run all tests
bin/rails test:system       # Run system tests
bin/rubocop                 # Lint code
bin/ci                      # Run full CI suite
```

## API

ClawDeck exposes a REST API for agent integrations:

```bash
# List projects
curl -H "Authorization: Bearer YOUR_TOKEN" https://your-clawdeck/api/v1/projects

# Create a task
curl -X POST -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"task": {"name": "Research topic X"}}' \
  https://your-clawdeck/api/v1/inbox/tasks
```

See [API Documentation](docs/API.md) for full details.

## Deployment

ClawDeck can be self-hosted on any VPS. See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed instructions.

For managed hosting, visit [clawdeck.com](https://clawdeck.com) (coming soon).

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License — see [LICENSE](LICENSE) for details.

## Links

- 🌐 **Website:** [clawdeck.io](https://clawdeck.io)
- 📖 **Docs:** [clawdeck.io/docs](https://clawdeck.io/docs)
- 💬 **Discord:** [Join the community](https://discord.gg/openclaw)
- 🐙 **GitHub:** [clawdeckio/clawdeck](https://github.com/clawdeckio/clawdeck)

---

Built with 🦞 by the OpenClaw community.
