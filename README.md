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
- **Authentication** via GitHub OAuth or email/password

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

### Authentication Setup

ClawDeck supports two authentication methods:

1. **Email/Password** — Works out of the box, no configuration needed
2. **GitHub OAuth** — Optional, requires setup (recommended for production)

#### Setting up GitHub OAuth

1. Go to [GitHub Developer Settings](https://github.com/settings/developers)
2. Click **New OAuth App**
3. Fill in the application details:
   - **Application name:** ClawDeck (or your preferred name)
   - **Homepage URL:** `http://localhost:3000` (or your production URL)
   - **Authorization callback URL:** `http://localhost:3000/auth/github/callback`
4. Click **Register application**
5. Copy the **Client ID** and generate a **Client Secret**
6. Add the credentials to your environment:

```bash
# For development, create a .env file in the project root:
GITHUB_CLIENT_ID=your_client_id_here
GITHUB_CLIENT_SECRET=your_client_secret_here
```

For production, set these as environment variables on your server or add them to your deployment configuration.

Once configured, users will see a "Continue with GitHub" button on the login and signup pages. Without these variables, only email/password authentication is available.

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
