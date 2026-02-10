# Night Runs: ComfyUI + n8n (23:00–08:00 ART)

## MVP in 2 nights (do this first)

### Night 1 — “Static ads factory” (SDXL)
1. **Stand up ComfyUI API on the Windows RTX 3080 node** (Docker Desktop/WSL2 or native) and confirm:
   - `POST /prompt` queues a workflow
   - `GET /history/{prompt_id}` returns outputs
   - `GET /view?filename=...&subfolder=...&type=output` retrieves the image
   - Optional realtime: WebSocket `/ws` for progress/events
   (These endpoints are the standard ComfyUI server routes used by most automation examples.)
2. **Export one “Static Ad” workflow as API JSON** (ComfyUI: *Export (API)*), store in `marketing/comfy/workflows/static_ad_v1.json`.
3. **Create an n8n workflow**:
   - Schedule Trigger (23:00) → Create “creative jobs” → HTTP Request (ComfyUI `/prompt`) → Poll `/history/{id}` → Fetch previews via `/view` → Telegram send media group → Telegram inline approval (✅/❌) → Log result.
4. **Artifact pipeline** (filesystem only, no DB yet):
   - Jobs as JSON in `marketing/night-runs/queue/`
   - Results in `marketing/night-runs/runs/YYYY-MM-DD/`
5. **Ship a loop**: generate 50–200 images with parameter sweeps (seeds + LoRA toggles) and a basic heuristic score (sharpness + OCR text check).

### Night 2 — “UI-anchored” + “Video teaser”
1. Add **UI anchoring** via ControlNet / IP-Adapter (screenshot → keep layout stable, insert product).
2. Add **lightweight video** run:
   - Wan2.1 **1.3B** profile for RTX 3080 10GB (short 4–6s, 480p), export a Comfy workflow.
3. Add “best-of” selection → Telegram approval → **publish-ready packages** (1080×1350, 1080×1920, 1080×1080 + MP4).

---

## 1) Night run objectives

### Primary objectives (every night)
1. **Template iteration**: Improve 1–2 “golden” Comfy workflows (static + UI-anchored).
2. **LoRA selection**: Test a small LoRA set per product/category (on/off + weights).
3. **Prompt variants**:
   - Hook/angle variants (benefit-led, price-led, social proof)
   - Visual style variants (clean studio, lifestyle, minimal flat-lay)
4. **Video snippets (if enabled)**:
   - Generate short reels (4–6 seconds) as “attention grabbers”
   - Keep compute bounded (few frames/res, low batch)

### Secondary objectives (weekly)
- Build a “winning prompt + workflow + LoRA recipe” library per product
- Create reusable control images/masks for UI-anchored ads
- Measure downstream performance (once publishing loop exists)

---

## 2) Scheduling: nightly windows, throttles, stop conditions

### Time window
- **Active window**: **23:00–08:00 ART**
- **Warm-up**: 22:45–23:00 (model pre-load, disk check, queue check)
- **Cool-down**: 07:30–08:00 (final selection + Telegram summary + cleanup)

### Concurrency & throttles (RTX 3080 10GB)
- **Images (SDXL)**: queue sequentially; allow limited overlap only if VRAM stable.
  - Default: **1 job at a time** (reliable, reproducible)
  - Optional: 2 parallel only for low-res / light workflows.
- **Video (Wan2.1)**: never parallelize on 10GB; run in dedicated “video slice” blocks.

### Stop conditions (circuit breakers)
Stop the run (and notify Telegram) when any triggers:
- **GPU OOM** > N times (e.g., 3) in 10 minutes
- **Average job latency** exceeds threshold (e.g., >8 min/image for SDXL base) → implies swap/offload misconfigured
- **Disk free space** below threshold (e.g., <50 GB on output volume)
- **Queue backlog** too large (e.g., >2000 items) → pause and require manual resume
- **Failure rate** > X% (e.g., >30% in last 50 jobs)

### Nightly “run modes”
- **Exploration mode** (Mon–Thu): wider sweeps, more novelty
- **Exploitation mode** (Fri/Sat): produce publish-ready batches from proven recipes
- **Maintenance mode** (Sun): cleanup, library updates, workflow refactors

---

## 3) Input data model: Creative Job JSON schema

Use a filesystem queue of JSON jobs. Each job expands into many “variants”.

### File location
- `marketing/night-runs/queue/job_<timestamp>_<slug>.json`

### JSON Schema (v1)
```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "CreativeJob",
  "type": "object",
  "required": ["job_id", "created_at", "product", "goal", "platforms", "assets", "copy", "generation"],
  "properties": {
    "job_id": {"type": "string"},
    "created_at": {"type": "string", "description": "ISO-8601"},
    "priority": {"type": "integer", "minimum": 0, "maximum": 100, "default": 50},

    "product": {
      "type": "object",
      "required": ["sku", "name", "brand"],
      "properties": {
        "sku": {"type": "string"},
        "name": {"type": "string"},
        "brand": {"type": "string"},
        "category": {"type": "string"},
        "price": {"type": ["number", "string"]},
        "brand_colors": {"type": "array", "items": {"type": "string", "description": "HEX"}},
        "fonts": {"type": "array", "items": {"type": "string"}}
      }
    },

    "goal": {
      "type": "object",
      "required": ["objective"],
      "properties": {
        "objective": {"type": "string", "enum": ["awareness", "traffic", "leads", "sales", "retargeting"]},
        "offer": {"type": "string"},
        "cta": {"type": "string"},
        "constraints": {"type": "array", "items": {"type": "string"}}
      }
    },

    "platforms": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["platform", "format"],
        "properties": {
          "platform": {"type": "string", "enum": ["instagram", "facebook"]},
          "format": {"type": "string", "enum": ["feed_1x1", "feed_4x5", "story_9x16", "reel_9x16", "carousel_4x5"]},
          "deliverable": {"type": "string", "enum": ["image", "video"]}
        }
      }
    },

    "assets": {
      "type": "object",
      "required": ["product_images"],
      "properties": {
        "product_images": {"type": "array", "items": {"type": "string"}},
        "base_ui_screens": {"type": "array", "items": {"type": "string"}},
        "masks": {"type": "array", "items": {"type": "string"}},
        "style_refs": {"type": "array", "items": {"type": "string"}},
        "logo": {"type": "string"}
      }
    },

    "copy": {
      "type": "object",
      "required": ["headline", "subheadline"],
      "properties": {
        "headline": {"type": "string"},
        "subheadline": {"type": "string"},
        "hashtags": {"type": "array", "items": {"type": "string"}},
        "language": {"type": "string", "default": "es-AR"}
      }
    },

    "generation": {
      "type": "object",
      "required": ["workflow", "seed_strategy", "variants"],
      "properties": {
        "workflow": {
          "type": "object",
          "required": ["template_id", "workflow_path"],
          "properties": {
            "template_id": {"type": "string"},
            "workflow_path": {"type": "string"},
            "inputs_map": {
              "type": "object",
              "description": "Mapping from job fields -> ComfyUI node inputs"
            }
          }
        },

        "seed_strategy": {
          "type": "object",
          "required": ["mode"],
          "properties": {
            "mode": {"type": "string", "enum": ["fixed", "random", "sequence"]},
            "seed": {"type": "integer"},
            "seed_start": {"type": "integer"},
            "count": {"type": "integer"}
          }
        },

        "variants": {
          "type": "object",
          "properties": {
            "prompt_variants": {"type": "array", "items": {"type": "string"}},
            "negative_variants": {"type": "array", "items": {"type": "string"}},
            "loras": {
              "type": "array",
              "items": {
                "type": "object",
                "required": ["name", "path"],
                "properties": {
                  "name": {"type": "string"},
                  "path": {"type": "string"},
                  "weights": {"type": "array", "items": {"type": "number"}},
                  "on_off": {"type": "boolean", "default": true}
                }
              }
            },
            "samplers": {"type": "array", "items": {"type": "string"}},
            "steps": {"type": "array", "items": {"type": "integer"}},
            "cfg": {"type": "array", "items": {"type": "number"}},
            "denoise": {"type": "array", "items": {"type": "number"}},
            "controlnet": {
              "type": "array",
              "items": {
                "type": "object",
                "required": ["type", "weights"],
                "properties": {
                  "type": {"type": "string", "enum": ["canny", "depth", "lineart", "tile", "pose"]},
                  "weights": {"type": "array", "items": {"type": "number"}}
                }
              }
            }
          }
        }
      }
    }
  }
}
```

### Seed strategy guidance
- **Exploration**: `sequence` with `seed_start` fixed per job (reproducible)
- **Exploitation**: `fixed` seed for “hero” renders + slight prompt/LoRA tweaks

---

## 4) Batch strategy (how to generate “lots” without chaos)

### Variant expansion approach
Treat each job as a cartesian product, but cap growth:
- Prompt variants: 5–10
- Seeds: 10–30
- LoRA weights: 0.4 / 0.7 / 1.0 (and off)
- Denoise sweep (img2img/inpaint): 0.25–0.55
- ControlNet weight sweep: 0.4–0.9

**Hard cap per job**: 200–800 renders (images) unless explicitly “deep search”.

### Recommended sweeps (starter)
**Static SDXL (txt2img):**
- Steps: [20, 28]
- CFG: [4.5, 6.0]
- Sampler: DPM++ 2M Karras (and one alt)
- Resolution: generate native close to target ratio (avoid extreme upscales)

**UI-anchored (img2img / inpaint):**
- Denoise: [0.25, 0.35, 0.45]
- ControlNet weights: [0.55, 0.75, 0.9]
- IP-Adapter weight: [0.5, 0.7, 0.85] (if used)

**Video (Wan2.1 1.3B):**
- Frames: small set (e.g., 49–81)
- Resolution: 480p first; only try 720p after profiling
- 1 seed sweep (3–8 seeds)

### “Bandit” improvement loop (night-to-night)
- Start with 80% exploration / 20% exploitation.
- After collecting scores + human picks, shift budget to templates/LoRAs with higher acceptance.

---

## 5) Scoring & selection (automated + human)

### Automated heuristics (per output)
Store a `score.json` per artifact with components:

1. **Sharpness** (focus/edge energy)
   - Laplacian variance or Tenengrad score.
2. **Text legibility** (OCR)
   - Run OCR (e.g., Tesseract) on the final composite.
   - Score by: presence of required tokens (brand, product, price) and confidence.
3. **Brand color compliance**
   - Extract dominant palette; compare to `brand_colors` (ΔE or simple RGB distance).
4. **UI integrity checks** (for UI-anchored ads)
   - SSIM between generated UI regions and base screenshot (mask UI area).
   - Penalize if SSIM below threshold (layout drift).
5. **No obvious artifacts**
   - Simple NSFW/defect heuristics (optional local classifier), or detect extreme noise.

### Selection policy
- Keep top **K per variant cluster** (avoid 20 near-duplicates).
- Promote top **N overall** to Telegram approval.

### Human approval loop (Telegram)
- Send 10–30 candidates as previews with:
  - Template ID, seed, LoRAs, weights, key params
  - Inline buttons: ✅ Approve / ⭐ Favorite / ❌ Reject
- Approved artifacts are copied (or symlinked) into `publish/`.

---

## 6) Artifact management: folders, naming, metadata

### Folder structure
```
marketing/night-runs/
  queue/
  runs/
    2026-02-09/
      job_<id>/
        inputs/
        variants/
          v0001/
            out/
              img_0001.png
              img_0001.preview.jpg
            meta/
              params.json
              score.json
              comfy_history.json
        selection/
          shortlisted.json
          approved.json
        publish/
          IG_feed_4x5_1080x1350.png
          IG_story_1080x1920.png
```

### Naming convention
- Variant id: `vNNNN` (stable ordering)
- Output: `img_<rank>.png` + `*.preview.jpg`
- Always store:
  - `params.json` (all final parameters)
  - `comfy_history.json` (raw /history payload)
  - `score.json`

### Metadata sidecars
`params.json` should include:
- template/workflow version
- seed
- model + LoRA list + hashes
- sampler/steps/cfg/denoise
- controlnet/ip-adapter settings

---

## 7) Integration plan with n8n

### Architecture (incremental)
**Phase A (filesystem queue)**
- n8n reads job JSON files from shared folder (SMB mount or local path).

**Phase B (DB queue)**
- Move queue state to Postgres (dashboard DB or dedicated). Files remain as artifacts.

### Triggers
1. **Schedule Trigger** (nightly 23:00)
2. **Webhook Trigger** (manual “run now”, or inject new job from other systems)
3. **Telegram Trigger** (optional: create job from chat command)

### Queue & state machine
Statuses:
- `queued` → `running` → `scored` → `shortlisted` → `awaiting_approval` → `approved|rejected|archived`

### ComfyUI execution calls
Standard pattern:
1. **POST** `http://<comfy-host>:8188/prompt`
   - Body: `{ "prompt": <workflow_graph_json>, "client_id": "n8n" }`
2. Poll **GET** `http://<comfy-host>:8188/history/<prompt_id>` until outputs exist
3. Download previews via **GET** `http://<comfy-host>:8188/view?filename=...&subfolder=...&type=output`
4. Optional: WebSocket `/ws` to track progress without polling.

### Storing results
- Store images on disk (preferred) + reference paths in n8n execution data
- Keep full run summary JSON for audit

### Telegram previews
- Send compressed JPG previews first (fast, low size)
- Send originals only when approved or requested

### Approval → publish (FB/IG) + logging
- Approval marks artifact as “publishable” and generates:
  - Caption text from job copy + hashtags
  - Platform-specific crops/resizes
- Publishing (later stage) via Meta Graph API requires IG page linking; until then:
  - Export publish folder and keep a “manual publish checklist”
- Log:
  - job_id, artifact_id, approval user, timestamp
  - parameters for reproducibility

---

## 8) Safety / ops

### Resource limits
- Enforce max queue depth and max renders/night
- Limit video jobs to a fixed time slice (e.g., 01:00–03:00)

### Disk management
- Nightly cleanup policy:
  - Keep all metadata forever (small)
  - Keep only top K images per job after 7 days
  - Archive approved/published assets permanently

### Reproducibility
- Always persist:
  - seed + prompt + negative prompt
  - workflow JSON version
  - model/LoRA hashes

### Failure modes & circuit breakers
- ComfyUI restart loop: if `/prompt` fails repeatedly, pause and notify.
- Model missing: mark job as blocked (don’t keep retrying).
- OOM: automatically reduce resolution / disable refiner / lower batch for next attempt.

---

## 9) Recommended next steps (after MVP)
- Add a small local “scorer” service (Python) called by n8n
- Add “active learning”: use approved set to bias future prompts/LoRAs
- Add a “workflow registry” with versioning and compatibility checks

---

## References
- ComfyUI API patterns commonly used for automation: `/prompt`, `/history/{prompt_id}`, `/view`, WebSocket `/ws` (see examples and docs referenced in web search results such as 9elements blog and comfy.org docs).
- n8n + ComfyUI automation examples (community nodes and guides exist; you can implement equivalent via plain HTTP nodes).
- Wan2.1 VRAM notes: the 1.3B model is reported around ~8GB VRAM in common benchmarks; suitable for RTX 3080 10GB with conservative settings.
