# 📊 Marketing Docs Endpoint

**URL:** http://192.168.100.186:4001/marketing

## Overview

The `/marketing` endpoint provides a browsable, searchable static site for all Futura Sistemas marketing documentation including:

- 📋 **Plans** — Master plans, launch strategies
- 🔬 **Research** — Market intelligence, SEO plans, competitive analysis
- 💬 **Prompts** — AI prompts for content generation
- 📅 **Calendars** — Content calendars, posting schedules
- 🎨 **Generated Assets** — Images, graphics, brand materials

## Usage

### Accessing the Docs

1. **Web UI:** Navigate to http://192.168.100.186:4001/marketing
2. **Direct links:** Each file has a View (HTML) and Raw (download) link
3. **Search:** Use the search box to filter by title or path

### Adding New Documents

1. Add markdown (`.md`) or image files to:
   ```
   ~/.openclaw/workspace/marketing/
   ```
   
2. Organize by category:
   - `research/` — Research docs
   - `prompts/` — AI prompts
   - `calendar/` — Calendars
   - `content/` — Content pieces
   - `generated/` — Generated assets
   - Root level — Plans

3. Rebuild the site:
   ```bash
   cd /home/ggorbalan/clawdeck
   ruby scripts/build_marketing_site.rb
   ```

### Rebuild Script

The build script is idempotent and can be run anytime:

```bash
# From ClawDeck directory
ruby scripts/build_marketing_site.rb

# Or with full path
ruby /home/ggorbalan/clawdeck/scripts/build_marketing_site.rb
```

The script:
- Scans all files in `~/.openclaw/workspace/marketing/`
- Converts markdown to viewable HTML (client-side rendering via marked.js)
- Copies images with thumbnails in the index
- Generates a searchable index page
- Outputs to `/home/ggorbalan/clawdeck/public/marketing/`

### Automation

To auto-rebuild when files change, you could add a cron job or file watcher:

```bash
# Example: rebuild every hour
0 * * * * cd /home/ggorbalan/clawdeck && ruby scripts/build_marketing_site.rb
```

## Technical Details

- **Route:** GET `/marketing` → redirects to `/marketing/index.html`
- **Static files:** Served directly by Rails from `public/marketing/`
- **No database:** Pure static site, zero Rails overhead
- **Dark theme:** Matches Futura Systems branding
- **Mobile responsive:** Works on all devices

## Files Created

| Path | Description |
|------|-------------|
| `/home/ggorbalan/clawdeck/scripts/build_marketing_site.rb` | Build script |
| `/home/ggorbalan/clawdeck/public/marketing/` | Generated static site |
| `/home/ggorbalan/clawdeck/config/routes.rb` | Route added |

---

*Last updated: 2026-02-09*
