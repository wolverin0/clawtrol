# Dependency Manifest

<!--
═══════════════════════════════════════════════════════════════════════════════
WHAT THIS FILE IS

The single source of truth for which dependencies and which versions are in
use. Loaded on demand when the agent needs to add or upgrade a dependency.

WHY THIS FILE EXISTS

The "framework version drift" failure mode (Softr/Anthropic field reports):
  "The AI assumes you're on version 15 of a library. The next session,
   working from different context, it generates code targeting version 16.5.
   Both seem fine in isolation. Over time, your codebase contains code
   written for incompatible versions of the same library."

This file is the agent's pinned reference. It also records WHY a version
is pinned, which the package.json / requirements.txt cannot.
═══════════════════════════════════════════════════════════════════════════════
-->

## Runtime versions

| Runtime | Version | Why pinned |
|---|---|---|
| Python | 3.11.x | 3.12 broke our `asyncio` task-cancellation pattern. Do not upgrade. |
| Node | 20.x LTS | Vercel deployment target. |

## Production dependencies

<!--
For each: name, exact version, why we use it, what NOT to confuse it with.
The "what not to confuse" column prevents the model from importing the
wrong-but-similar package.
-->

| Package | Version | Purpose | Do NOT use instead |
|---|---|---|---|
| fastapi | 0.115.0 | HTTP framework | flask, starlette directly |
| sqlalchemy | 2.0.30 | ORM (we use 2.0 async style) | 1.x sync style |
| pydantic | 2.7.x | Validation | dataclasses, marshmallow |
| httpx | 0.27.0 | Async HTTP client | requests, aiohttp |
| supabase | 2.5.0 | Supabase client | postgrest-py directly |

## Forbidden dependencies

<!--
Packages the model has been known to suggest that we explicitly do NOT
want here. Prevents a common failure mode: the model defaults to whatever
package is most-mentioned in its training data, which is rarely the right
choice for your specific repo.
-->

- ❌ `requests` — synchronous, breaks our async pattern. Use `httpx`.
- ❌ `aiohttp` — we standardized on `httpx`. Don't add a second HTTP client.
- ❌ `flask` — we use FastAPI. Do not introduce a second framework.
- ❌ `pymongo`, `mongoengine` — we use PostgreSQL exclusively
- ❌ `pydantic` v1 patterns (`.dict()`, `class Config:`) — we are on v2 (`.model_dump()`, `model_config = ConfigDict(...)`)

## Version compatibility traps

<!--
Specific known-bad combinations. Each entry should be one sentence the
agent can immediately understand.
-->

- `sqlalchemy` 2.x requires `async_sessionmaker`, NOT `sessionmaker(... class_=AsyncSession)`. The latter pattern works but is deprecated.
- `pydantic` 2.x: `model_dump()` not `dict()`, `model_validate()` not `parse_obj()`, `ConfigDict(...)` not `class Config:`.
- `fastapi` 0.115+: lifespan handlers are async context managers, NOT `@app.on_event`.
- `httpx` does NOT auto-decode `gzip` bodies for streaming responses; check `Content-Encoding` manually.

## Before adding any new dependency

1. ☐ Read this file. Is there already a package serving this concern?
2. ☐ If yes, use it. Do not add a parallel one.
3. ☐ If no, justify the addition: what does it do that we cannot do with current dependencies?
4. ☐ Check the package's last release date. If >12 months stale, find an alternative.
5. ☐ Check the package's number of maintainers. If 1, treat as risky.
6. ☐ Pin the exact version (no `^`, `~`, `>=`).
7. ☐ Add an entry to this file in the same commit as the install.

## Known-deprecated patterns we still have somewhere

<!--
Be honest about what's old in the codebase. The agent will trust this file
more than its training data, so listing the truth here prevents it from
"helpfully" using the deprecated pattern when it sees one.
-->

- `app/legacy/` directory: pydantic v1 patterns. Do not extend. Migrate when touched.
- `services/payments/v1/`: kept for old webhook handlers. New code goes in `services/payments/v2/`.

<!-- scaffold:filled 2026-04-27T12:31:51Z -->

## Auto-detected dependencies

Below: dependencies extracted from manifest files. Add the
**why** column manually — especially the "do not upgrade past X"
notes for libraries with breaking changes you've hit.

### Ruby (`Gemfile`)

```ruby
gem "rails", "~> 8.1.0"
gem "propshaft"
gem "pg", "~> 1.6"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "tailwindcss-rails"
gem "jbuilder"
gem "bcrypt", "~> 3.1.7"
gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"
gem "bootsnap", require: false
gem "dotenv-rails", groups: [ :development, :test ]
gem "image_processing", "~> 1.2"
gem "rack-attack"
gem "omniauth"
gem "omniauth-github"
gem "omniauth-rails_csrf_protection"
gem "pagy"
gem "redcarpet"
gem "diffy"
gem "chartkick", "~> 5.2"
gem "groupdate", "~> 6.7"
gem "sentry-ruby", "~> 5.17"
gem "sentry-rails", "~> 5.17"
```

