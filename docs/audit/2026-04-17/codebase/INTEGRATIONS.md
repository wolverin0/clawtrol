# ClawTrol — External Integrations

_Dated: 2026-04-17_

ClawTrol is a thin orchestration UI; most intelligence lives in OpenClaw (the gateway/runtime) and downstream LLM providers. Integrations are enumerated below with the file that owns the call and the env vars that configure them.

## 1. OpenClaw Gateway (primary integration)

The gateway is a per-user HTTP endpoint (`user.openclaw_gateway_url`) that exposes everything through `POST /tools/invoke` plus a `POST /hooks/wake` fire-and-forget wake endpoint. Bearer auth uses either the user-scoped hook token or gateway token.

- `app/services/openclaw_gateway_client.rb` — `Net::HTTP` client. Methods: `spawn_session!(model:, prompt:)` (invokes `sessions_spawn` tool), `sessions_list`, `session_detail`, `health` (`session_status`), `channels_status` (`gateway` action `config.get`). 5s open / 30s read timeouts.
- `app/services/openclaw_webhook_service.rb` — posts wake pings to `<gateway>/hooks/wake`. Headers: `Authorization: Bearer <token>` and `X-OpenClaw-Token`. 5s timeouts. Callers: `notify_task_assigned`, `notify_auto_claimed`, `notify_auto_pull_ready`, `notify_runner_summary`.
- `app/jobs/nightshift_runner_job.rb:50` and `app/jobs/factory_runner_job.rb:48` — direct `/hooks/wake` posts.
- `app/services/agent_auto_runner_service.rb` — reads `user.openclaw_gateway_url` (fallback `ENV["OPENCLAW_GATEWAY_URL"]`) and `user.openclaw_hooks_token` / `user.openclaw_gateway_token`.
- `app/services/openclaw_memory_search_health_service.rb` — health probe of gateway memory tool.
- `app/services/openclaw_models_service.rb` — shells out to `openclaw models list --json` via `Open3` (5-min Rails cache) to enumerate providers; labels 12 providers including `zai`, `anthropic`, `openai-codex`, `ollama`, `ollama-cloud`, `openrouter`, `groq`, `cerebras`, `mistral`, `google`, `google-gemini-cli`, `github-copilot`.
- `app/services/model_catalog_service.rb` — merges gateway model list with per-user task/persona history (5-min cache per user).
- `app/services/debate_review_service.rb` — multi-model review gate that spawns `gemini3` / `opus` / `glm` / `codex` sessions via the gateway and polls transcripts, falling back to a local rubric if gateway is unreachable (`DEBATE_REVIEW_MAX_WAIT_SECONDS`, default 45s).
- `app/models/task/agent_integration.rb` — per-task gateway interactions.
- `app/services/session_resolver_service.rb` + `app/services/transcript_watcher.rb` + `app/services/transcript_parser.rb` — read OpenClaw transcript files from `~/.openclaw/agents/main/sessions/*.jsonl` directly from disk.

**Envelope env vars**: `OPENCLAW_GATEWAY_URL`, `OPENCLAW_GATEWAY_TOKEN`, `HOOKS_TOKEN` / `CLAWTROL_HOOKS_TOKEN`, `CLAWTROL_API_TOKEN`.

## 2. GitHub OAuth + API

- **Login**: `config/initializers/omniauth.rb` registers `:github` via `omniauth-github` with `scope: "user:email"`. Gated on `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET`. Render free plan expects callback on the deployed host.
- **CLI-driven repo ops**: `app/services/factory_github_service.rb` shells out to `/home/ggorbalan/.local/bin/gh` and `/usr/bin/git` against `~/factory-workspaces/<slug>`. Actions: `clone!`, branch checkout, PR creation, default-branch detection. No REST calls — relies on `gh` auth of the host user.

## 3. Telegram Bot API

- `app/services/external_notification_service.rb` — `POST https://api.telegram.org/bot<TOKEN>/sendMessage` via `Net::HTTP.post_form`. Retries with 1s/5s/30s backoff on missing `message_id`. Targets `task.origin_chat_id` + `origin_thread_id` or the Mission Control default (chat = `CLAWTROL_TELEGRAM_CHAT_ID`, fallback `TELEGRAM_CHAT_ID`; thread defaults to `1`). Fires on `task.status in [in_review, done]` via `notify_task_completion`.
- `app/services/telegram_init_data_validator.rb` — validates Telegram Mini App initData (HMAC-SHA256 over sorted params, 5-min freshness). Bot token sourced from user record.
- `config/initializers/guardrails.rb` + `CatastrophicGuardrailsJob` — optional DB-drop alerts via `CLAWTROL_TELEGRAM_BOT_TOKEN` + `CLAWTROL_TELEGRAM_ALERT_CHAT_ID`, only when `CLAWDECK_GUARDRAILS_ENABLED=true`.

**Env vars**: `CLAWTROL_TELEGRAM_BOT_TOKEN` (preferred), `TELEGRAM_BOT_TOKEN`, `CLAWTROL_TELEGRAM_CHAT_ID`, `TELEGRAM_CHAT_ID`, `CLAWTROL_TELEGRAM_ALERT_CHAT_ID`.

## 4. Z.AI (GLM) direct API

- `app/services/ai_suggestion_service.rb` — direct `POST https://api.z.ai/api/coding/paas/v4/chat/completions` using `model: "glm-4.7-flash"`. API key comes from the user record (`user.ai_api_key`), not env. Used for: task follow-up suggestions, description enhancement. Falls back to deterministic suggestions if key missing.

## 5. OpenAI Images API

- `app/services/marketing_image_service.rb` — `POST https://api.openai.com/v1/images/generations` via `Net::HTTP`. API key from `ENV["OPENAI_API_KEY"]`. Supports 1024x1024, 1792x1024, 1024x1792. Templates: `ad-creative`, `carousel-slide`, `lifestyle-shot`, `background-swap`, `feature-highlight`. Product contexts for `futuracrm`, `futurafitness`, `optimadelivery`, `futura`.

## 6. Gemini CLI (OAuth, no API key)

- `app/jobs/process_saved_link_job.rb` — calls `gemini` CLI via `Open3` to summarize saved links with a ClawTrol/OpenClaw relevance rubric. Includes SSRF protection (`SsrfProtection` concern blocks private IPs). Special-case fetcher for X/Twitter using the fxtwitter API (`https://api.fxtwitter.com`).

## 7. Qdrant + Ollama (RAG pipeline)

- `app/services/pipeline/qdrant_client.rb` — posts embeddings search to Qdrant.
  - `QDRANT_URL` default `http://192.168.100.186:6333`
  - `OLLAMA_URL` default `http://192.168.100.155:11434` (embeddings endpoint `/api/embed`)
  - `EMBEDDING_MODEL` default `qwen3-embedding:8b`
  - `QDRANT_COLLECTION` default `clawdeck`
- Used by `pipeline/context_compiler_service.rb`, `pipeline/triage_service.rb`, `pipeline/claw_router_service.rb`, `pipeline/orchestrator.rb`, `pipeline/auto_review_service.rb`.

## 8. n8n Webhook (social media publishing)

- `app/services/social_media_publisher.rb` — `POST` to `N8N_WEBHOOK_URL` (default `http://localhost:5678/webhook/social-media-post`). Payload includes `image_url`, `caption`, `hashtags`, per-platform toggles (Facebook, Instagram, LinkedIn, Twitter, YouTube, Pinterest, TikTok, Threads), `cta`, `product`. Timeouts degrade gracefully to a local queued warning.

## 9. Outbound Webhooks (user-defined)

- `app/services/external_notification_service.rb#send_webhook` — per-user `user.webhook_notification_url` posted with task JSON. Fires alongside Telegram on task completion.

## 10. Docker (Zerobitch fleet)

- `app/services/zerobitch/docker_service.rb` — shells Docker CLI to manage agent fleet containers.
- `app/services/zerobitch/metrics_store.rb` — polled by `ZerobitchMetricsJob`.

## 11. SMTP / Mail

- Action Mailer in production uses `:smtp` (`config/environments/production.rb`), host derived from `APP_BASE_URL`. Development uses `letter_opener` instead of sending.

## 12. LLM Debate (via OpenClaw only — no direct Anthropic/OpenAI keys)

- `app/services/debate_review_service.rb` is the only LLM-review path; it does NOT hold Anthropic, OpenAI, or Gemini API keys. All model calls are proxied through the OpenClaw gateway session for the task owner. Model aliases: `gemini -> gemini3`, `claude -> opus`, `glm -> glm`, `codex -> codex`.

## 13. Lobster Pipelines

- `app/services/lobster_runner.rb` — loads pipeline YAML from `lobster/*.lobster` (30s step timeout) and shells out to configured commands; approval gates persisted on the task record. In-house DSL, not a third-party integration, but it is the bridge for shell-invoked tools.

---

## Files Listed But NOT Read (secrets present)

- `/home/ggorbalan/clawdeck/.env`
- `/home/ggorbalan/clawdeck/.env.production.example`
- `/home/ggorbalan/clawdeck/config/credentials.yml.enc`
- `config/master.key` not present in tree; `RAILS_MASTER_KEY` expected from env (`render.yaml` marks it `sync: false`)

## Environment Variables Referenced by Integrations

`OPENCLAW_GATEWAY_URL`, `OPENCLAW_GATEWAY_TOKEN`, `HOOKS_TOKEN`, `CLAWTROL_HOOKS_TOKEN`, `CLAWTROL_API_TOKEN`, `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`, `CLAWTROL_TELEGRAM_BOT_TOKEN`, `TELEGRAM_BOT_TOKEN`, `CLAWTROL_TELEGRAM_CHAT_ID`, `TELEGRAM_CHAT_ID`, `CLAWTROL_TELEGRAM_ALERT_CHAT_ID`, `OPENAI_API_KEY`, `N8N_WEBHOOK_URL`, `QDRANT_URL`, `OLLAMA_URL`, `EMBEDDING_MODEL`, `QDRANT_COLLECTION`, `CLAWDECK_GUARDRAILS_ENABLED`, `CLAWDECK_GUARDRAILS_MODE`, `CLAWDECK_GUARDRAILS_INTERVAL_SECONDS`, `CLAWDECK_GUARDRAILS_DROP_PERCENT`, `APP_BASE_URL`, `PORT`, `DATABASE_URL`, `SECRET_KEY_BASE`, `RAILS_MASTER_KEY`, `AUTO_RUNNER_*`, `DEBATE_REVIEW_MAX_WAIT_SECONDS`, `CLAWTROLPLAYGROUND_DB_*`.
