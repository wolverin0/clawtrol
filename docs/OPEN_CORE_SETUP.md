# ClawDeck Open Core Setup Guide

Complete walkthrough for setting up ClawDeck as an open core project with a hosted platform.

---

## Overview

**Architecture:**
- `clawdeck.io` — Homepage + hosted app (single domain)
- `github.com/clawdeckio/clawdeck` — Public OSS repo (MIT)
- `github.com/clawdeckio/clawdeck-cloud` — Private repo (extends OSS with admin/billing)

**Principle:** OSS repo is the source of truth for core features. Private repo only *adds* cloud-specific code, never modifies core.

---

## Part 1: Domain Setup

### Current State
- `clawdeck.io` — needs to point to hosted app
- `app.clawdeck.io` — current app location (will deprecate)

### Steps

#### 1.1 Update DNS (Cloudflare or your DNS provider)
```
# Remove or redirect app.clawdeck.io
# Point clawdeck.io root to your server
A     @     → <server-ip>
CNAME www   → clawdeck.io
```

#### 1.2 Update Rails config

**config/environments/production.rb:**
```ruby
config.hosts << "clawdeck.io"
config.hosts << "www.clawdeck.io"
# Remove or keep app.clawdeck.io for redirect
```

#### 1.3 Update Nginx/Caddy config

**Option A: Caddy (recommended)**
```
clawdeck.io, www.clawdeck.io {
    reverse_proxy localhost:3000
}

# Redirect old subdomain
app.clawdeck.io {
    redir https://clawdeck.io{uri} permanent
}
```

**Option B: Nginx**
```nginx
server {
    listen 443 ssl;
    server_name clawdeck.io www.clawdeck.io;
    
    location / {
        proxy_pass http://localhost:3000;
        # ... proxy headers
    }
}

server {
    listen 443 ssl;
    server_name app.clawdeck.io;
    return 301 https://clawdeck.io$request_uri;
}
```

#### 1.4 Update all references
- [ ] README.md — already updated to clawdeck.io
- [ ] Any hardcoded URLs in the app
- [ ] OAuth callback URLs (GitHub, etc.)
- [ ] Email templates (if any)

---

## Part 2: Create Private Cloud Repo

### 2.1 Create the private repository

```bash
# On GitHub
# Create new private repo: clawdeckio/clawdeck-cloud
# Do NOT initialize with README (we'll set it up manually)
```

### 2.2 Set up local clone with upstream tracking

```bash
# Clone the public OSS repo as your base
git clone https://github.com/clawdeckio/clawdeck.git clawdeck-cloud
cd clawdeck-cloud

# Rename origin to upstream (OSS becomes upstream)
git remote rename origin upstream

# Add private repo as origin
git remote add origin git@github.com:clawdeckio/clawdeck-cloud.git

# Verify remotes
git remote -v
# origin    git@github.com:clawdeckio/clawdeck-cloud.git (fetch)
# origin    git@github.com:clawdeckio/clawdeck-cloud.git (push)
# upstream  https://github.com/clawdeckio/clawdeck.git (fetch)
# upstream  https://github.com/clawdeckio/clawdeck.git (push)

# Push to private repo
git push -u origin main
```

### 2.3 Create cloud-specific directory structure

```bash
# Create directories for cloud-only code
mkdir -p app/controllers/admin
mkdir -p app/views/admin
mkdir -p lib/cloud
mkdir -p config/cloud

# Create placeholder files
touch app/controllers/admin/.gitkeep
touch lib/cloud/.gitkeep
```

### 2.4 Add cloud-specific .gitignore entries (optional)

```bash
# Add to .gitignore if needed
echo "# Cloud-specific ignores" >> .gitignore
echo "config/cloud/*.local.yml" >> .gitignore
```

### 2.5 Create cloud initializer

**lib/cloud/engine.rb:**
```ruby
# frozen_string_literal: true

module Cloud
  ENABLED = ENV.fetch("CLAWDECK_CLOUD", "false") == "true"
  
  def self.enabled?
    ENABLED
  end
end
```

**config/initializers/cloud.rb:**
```ruby
require_relative "../../lib/cloud/engine"

if Cloud.enabled?
  Rails.logger.info "ClawDeck Cloud features enabled"
end
```

### 2.6 Document the setup

**Create CLOUD_README.md in private repo:**
```markdown
# ClawDeck Cloud (Private)

This repo extends the public ClawDeck OSS repo with cloud-specific features.

## Structure

- `upstream` remote → public OSS repo (source of truth)
- `origin` remote → this private repo

## Syncing with OSS

```bash
git fetch upstream
git merge upstream/main
# Resolve any conflicts
git push origin main
```

## Cloud-Only Features

- `/admin` — Admin dashboard
- Transactional emails
- Usage analytics
- Billing (future)

## Deployment

Deploy from this repo, not the public one.
Set `CLAWDECK_CLOUD=true` in production environment.
```

---

## Part 3: Add Admin Features (Cloud-Only)

### 3.1 Create Admin controller

**app/controllers/admin/base_controller.rb:**
```ruby
# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    before_action :require_admin!
    
    private
    
    def require_admin!
      unless Cloud.enabled? && current_user&.admin?
        redirect_to root_path, alert: "Not authorized"
      end
    end
  end
end
```

### 3.2 Create Admin dashboard

**app/controllers/admin/dashboard_controller.rb:**
```ruby
module Admin
  class DashboardController < BaseController
    def index
      @users_count = User.count
      @tasks_count = Task.count
      @boards_count = Board.count
    end
  end
end
```

### 3.3 Add admin routes (conditional)

**config/routes.rb:** (add at the end)
```ruby
if Cloud.enabled?
  namespace :admin do
    get "/", to: "dashboard#index"
    # Add more admin routes here
  end
end
```

### 3.4 Add admin flag to users

```bash
rails generate migration AddAdminToUsers admin:boolean
```

**Migration:**
```ruby
class AddAdminToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :admin, :boolean, default: false, null: false
  end
end
```

---

## Part 4: Sync Workflow

### Daily Development Workflow

```
┌─────────────────────────────────────────────────────┐
│                  OSS REPO (public)                  │
│            github.com/clawdeckio/clawdeck           │
│                                                     │
│  • All core development happens here                │
│  • Community PRs land here                          │
│  • This is the source of truth                      │
└─────────────────────┬───────────────────────────────┘
                      │
                      │ git fetch upstream
                      │ git merge upstream/main
                      ▼
┌─────────────────────────────────────────────────────┐
│               CLOUD REPO (private)                  │
│         github.com/clawdeckio/clawdeck-cloud        │
│                                                     │
│  • Pulls from OSS as upstream                       │
│  • Adds cloud-only features                         │
│  • Deployed to production                           │
└─────────────────────────────────────────────────────┘
```

### Sync Commands (run before each deploy)

```bash
cd clawdeck-cloud

# Fetch latest from OSS
git fetch upstream

# Merge OSS changes
git merge upstream/main

# If conflicts, resolve them (should be rare if cloud code is isolated)
# git add .
# git commit -m "Merge upstream"

# Push to private repo
git push origin main

# Deploy
# your-deploy-command
```

### Automated Sync (Optional GitHub Action)

**Create `.github/workflows/sync-upstream.yml` in private repo:**

```yaml
name: Sync with upstream OSS

on:
  schedule:
    - cron: '0 6 * * *'  # Daily at 6am UTC
  workflow_dispatch:  # Manual trigger

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          token: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Configure git
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
      
      - name: Add upstream
        run: git remote add upstream https://github.com/clawdeckio/clawdeck.git
      
      - name: Fetch upstream
        run: git fetch upstream
      
      - name: Merge upstream
        run: |
          git merge upstream/main --no-edit || {
            echo "Merge conflict detected. Manual intervention required."
            exit 1
          }
      
      - name: Push changes
        run: git push origin main
```

---

## Part 5: Production Deployment

### 5.1 Server setup

```bash
# On production server
cd /var/www

# Clone private repo (NOT the public one)
git clone git@github.com:clawdeckio/clawdeck-cloud.git clawdeck
cd clawdeck

# Set up environment
cp .env.example .env
# Edit .env and add:
# CLAWDECK_CLOUD=true
```

### 5.2 Environment variables

```bash
# Required for cloud features
CLAWDECK_CLOUD=true

# Standard Rails
RAILS_ENV=production
SECRET_KEY_BASE=<generated>
DATABASE_URL=postgres://...

# OAuth (GitHub)
GITHUB_CLIENT_ID=<your-client-id>
GITHUB_CLIENT_SECRET=<your-client-secret>
GITHUB_REDIRECT_URI=https://clawdeck.io/auth/github/callback

# Email (when ready)
# SMTP_HOST=...
# SMTP_PORT=...
```

### 5.3 Deploy script

**bin/deploy** (in private repo):
```bash
#!/bin/bash
set -e

echo "🦞 Deploying ClawDeck Cloud..."

# Sync with upstream first
git fetch upstream
git merge upstream/main --no-edit

# Push any changes
git push origin main

# SSH to server and deploy
ssh deploy@your-server << 'EOF'
  cd /var/www/clawdeck
  git pull origin main
  bundle install
  rails db:migrate
  rails assets:precompile
  touch tmp/restart.txt  # or your restart mechanism
EOF

echo "✅ Deployed!"
```

---

## Part 6: Checklist

### Initial Setup
- [ ] Create private repo `clawdeckio/clawdeck-cloud`
- [ ] Clone and set up remotes (upstream = OSS, origin = private)
- [ ] Push initial code to private repo
- [ ] Create cloud directory structure
- [ ] Add Cloud module and initializer
- [ ] Update DNS for clawdeck.io
- [ ] Update web server config (Nginx/Caddy)
- [ ] Update Rails hosts config
- [ ] Update OAuth callback URLs

### Cloud Features
- [ ] Add admin column to users table
- [ ] Create Admin::BaseController
- [ ] Create Admin::DashboardController
- [ ] Add conditional admin routes
- [ ] Create admin views

### Deployment
- [ ] Set up production server with private repo
- [ ] Configure environment variables (CLAWDECK_CLOUD=true)
- [ ] Set up deploy script
- [ ] (Optional) Set up auto-sync GitHub Action

### Cleanup
- [ ] Redirect app.clawdeck.io → clawdeck.io
- [ ] Update any remaining hardcoded URLs
- [ ] Make yourself admin: `User.find_by(email: "...").update(admin: true)`

---

## Summary

| Item | Location |
|------|----------|
| Homepage + App | clawdeck.io |
| OSS Source | github.com/clawdeckio/clawdeck |
| Cloud Source | github.com/clawdeckio/clawdeck-cloud (private) |
| Deploy From | clawdeck-cloud repo |
| Cloud Flag | `CLAWDECK_CLOUD=true` |

**Golden Rule:** All core development happens in the public OSS repo. Private repo only adds cloud-specific code and merges from upstream.

---

*Last updated: 2026-01-31*
