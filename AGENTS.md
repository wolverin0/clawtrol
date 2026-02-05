# AGENTS.md - ClawTrol Development Guide

This file provides guidance to Claude Code (claude.ai/code) and other AI coding assistants when working with this repository.

## Project Overview

**ClawTrol** is a Rails 8.1 mission control dashboard for AI agents. It provides:
- Task queue with agent assignment workflow
- Multi-board kanban organization
- Live agent transcript viewing
- Model routing (opus, sonnet, codex, gemini, glm)
- Validation system (command + debate)
- Follow-up task chaining
- Nightly/recurring task scheduling

Previously known as ClawDeck. Rebranded to ClawTrol in February 2026.

## Development Commands

### Initial Setup
```bash
bin/setup              # Install dependencies, prepare database, start server
bin/setup --skip-server  # Setup without starting the server
bin/setup --reset      # Setup with database reset
```

### Running the Application
```bash
bin/dev                # Start development server (web + Tailwind CSS watch)
bin/rails server       # Start web server only
bin/rails tailwindcss:watch  # Watch and rebuild Tailwind CSS
```

### Database
```bash
bin/rails db:prepare   # Create, migrate, and seed database
bin/rails db:migrate   # Run pending migrations
bin/rails db:reset     # Drop, create, migrate, seed
bin/rails db:seed:replant  # Truncate and reseed
```

### Testing
```bash
bin/rails test         # Run all unit/integration tests
bin/rails test:system  # Run system tests (Capybara + Selenium)
bin/rails test test/models/user_test.rb  # Run specific test file
bin/rails test test/models/user_test.rb:10  # Run specific test line
```

### Code Quality and Security
```bash
bin/rubocop            # Run RuboCop linter (Omakase Ruby style)
bin/rubocop -a         # Auto-correct offenses
bin/brakeman           # Security analysis
bin/bundler-audit      # Check for vulnerable gem versions
bin/importmap audit    # Check for vulnerable JavaScript dependencies
bin/ci                 # Run full CI suite (setup, linting, security, tests)
```

### Asset Management
```bash
bin/rails assets:precompile  # Precompile assets for production
bin/importmap pin <package>  # Pin JavaScript package from CDN
bin/importmap unpin <package>  # Unpin JavaScript package
```

### Deployment
```bash
ssh root@YOUR_SERVER_IP       # SSH to production VPS
systemctl status puma         # Check Puma status
systemctl status solid_queue  # Check Solid Queue status
systemctl restart puma        # Restart web server
systemctl restart solid_queue # Restart background jobs
tail -f /var/log/clawdeck/puma.log      # View application logs
tail -f /var/log/clawdeck/solid_queue.log  # View job logs
```

## Architecture

### Technology Stack
- **Ruby/Rails**: 3.3.1 / 8.1.0
- **Database**: PostgreSQL with multi-database setup (primary, cache, queue, cable)
- **Background Jobs**: Solid Queue (database-backed)
- **Caching**: Solid Cache (database-backed)
- **WebSockets**: Solid Cable (database-backed)
- **Email**: Resend API (passwordless authentication with 6-digit codes)
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS, importmap for JavaScript
- **Image Processing**: Active Storage with image_processing gem
- **Deployment**: DigitalOcean VPS + GitHub Actions auto-deploy
- **Web Server**: Puma with Nginx reverse proxy

### Application Structure
- **Module Name**: `ClawDeck` (config/application.rb) — module name retained for code compatibility
- **Product Name**: ClawTrol — used in UI and documentation
- **Solid Stack**: Uses solid_cache, solid_queue, and solid_cable instead of Redis
- **Hotwire-first**: Built for Turbo Drive navigation with minimal JavaScript
- **Asset Pipeline**: Propshaft for static assets, importmap-rails for JavaScript modules

### Key Models

#### User
- Email-based authentication with 6-digit verification codes (15-minute expiry)
- `has_many :boards` - Multiple kanban boards
- `has_many :tasks` - All user tasks
- `has_many :model_limits` - Rate limit tracking per model

#### Board
- `belongs_to :user`
- `has_many :tasks`
- Fields: name, icon (emoji), color
- Used for organizing tasks by project/context

#### Task
- `belongs_to :user`
- `belongs_to :board`
- `belongs_to :parent_task, optional: true` - For follow-ups
- **Statuses**: inbox, up_next, in_progress, in_review, done
- **Priorities**: none, low, medium, high
- **Models**: opus, sonnet, codex, gemini, glm
- **Agent fields**: assigned_to_agent, agent_session_id, agent_session_key
- **Validation fields**: validation_command, validation_status, validation_output
- **Review fields**: review_type, review_status, review_config, review_result
- **Nightly fields**: nightly, nightly_delay_hours
- **Recurring fields**: recurring, recurrence_rule, recurrence_time

#### ModelLimit
- `belongs_to :user`
- Tracks rate limits per model
- Fields: name, limited, resets_at, error_message
- Used for model fallback chain

### API Architecture

Base URL: `/api/v1`

#### Core Task Endpoints
- `GET /tasks` - List tasks (filters: status, assigned, board_id, etc.)
- `GET /tasks/:id` - Get single task
- `POST /tasks` - Create task
- `PATCH /tasks/:id` - Update task
- `DELETE /tasks/:id` - Delete task

#### Agent Workflow Endpoints
- `POST /tasks/spawn_ready` - Create task in_progress + assigned
- `POST /tasks/:id/link_session` - Connect OpenClaw session
- `POST /tasks/:id/agent_complete` - Complete task with output
- `GET /tasks/:id/agent_log` - Get agent transcript
- `POST /tasks/:id/handoff` - Hand off to different model

#### Review Endpoints
- `POST /tasks/:id/start_validation` - Start command validation
- `POST /tasks/:id/run_debate` - Start debate review
- `POST /tasks/:id/complete_review` - Complete review with result

#### Model Limit Endpoints
- `GET /models/status` - Get all model statuses
- `POST /models/best` - Get best available model
- `POST /models/:name/limit` - Record rate limit
- `DELETE /models/:name/limit` - Clear rate limit

#### Board Endpoints
- `GET /boards` - List boards
- `GET /boards/:id` - Get board (optionally with tasks)
- `POST /boards` - Create board
- `PATCH /boards/:id` - Update board
- `DELETE /boards/:id` - Delete board

### Authentication

API authentication via Bearer token:
```
Authorization: Bearer YOUR_TOKEN
```

Agent identity via headers:
```
X-Agent-Name: Otacon
X-Agent-Emoji: 📟
```

### Routes Structure
```ruby
namespace :api do
  namespace :v1 do
    resources :boards
    resources :tasks do
      collection do
        post :spawn_ready
        get :recurring
      end
      member do
        post :agent_complete
        post :link_session
        get :agent_log
        post :handoff
        post :start_validation
        post :run_debate
      end
    end
  end
end
```

### CI Pipeline
GitHub Actions runs on PR and push to main:
1. **scan_ruby**: Brakeman + bundler-audit
2. **scan_js**: importmap audit
3. **lint**: RuboCop
4. **test**: Rails tests with PostgreSQL
5. **system-test**: Capybara tests

### Deployment Flow
Auto-deploy on push to main:
1. SSH to VPS
2. Pull latest code
3. Bundle install
4. Backup databases
5. Run migrations
6. Precompile assets
7. Restart Puma + Solid Queue

### Background Jobs
- `RunValidationJob` - Execute validation commands
- `RunDebateJob` - Run multi-model debate reviews

### Frontend Controllers (Stimulus)
- `sortable_controller.js` - Drag-and-drop task ordering
- `task_modal_controller.js` - Task detail modals
- `live_activity_controller.js` - Real-time transcript polling
- `dropdown_controller.js` - UI dropdowns
- `flash_controller.js` - Flash messages

### Development Guidelines
1. Never default to regular JS if Turbo/Hotwire can accomplish the same thing
2. Follow Rails conventions and DRY principles
3. Deploy via GitHub Actions by pushing to main branch
4. Use Solid Queue for background jobs, not Sidekiq
5. Test with bin/rails test before pushing

## Documentation

- `docs/AGENT_INTEGRATION.md` - Complete agent integration guide
- `docs/OPENCLAW_INTEGRATION.md` - OpenClaw-specific setup
- `docs/API_REFERENCE.md` - Full API endpoint reference
