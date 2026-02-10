# Model / LoRA Library Policy (ComfyUI + Local Only)

This policy makes model usage **repeatable**, **license-aware**, and **rollback-safe** for nightly ComfyUI runs on the Windows RTX 3080 (10GB).

---

## 0) Principles
1. **Reproducibility is the product**: every approved creative must be regeneratable.
2. **Pin everything**: model filename + upstream URL + hash + version tag.
3. **Keep VRAM reality in mind**: avoid workflows that only work on 24GB+.
4. **License-first**: do not mix “non-commercial” assets into commercial pipelines.
5. **Small curated sets beat giant dumps**: nightly iteration requires fast selection.

---

## 1) Storage layout

### Base root
- Recommended root on the Windows node (fast SSD):
  - `D:/ai/models/`

### ComfyUI expected subfolders (typical)
Map these into ComfyUI `models/` (or mount them in Docker):
```
models/
  checkpoints/
  loras/
  controlnet/
  clip/
  vae/
  ipadapter/
  upscale_models/
  embeddings/
  sams/
  animatediff/
  video/
```

### “Manifest” directory (source-of-truth)
Keep manifests in the Linux marketing hub for audit:
- `/home/ggorbalan/.openclaw/workspace/marketing/model-manifests/`

Each manifest corresponds to one file and captures:
- origin URL
- license
- hash
- install target path

---

## 2) Model classes & allowed sources

### Checkpoints / base models (SDXL)
**Allowed sources**:
- Hugging Face (HF)
- Official Stability AI distributions
- CivitAI (only if license permits your use)

**Policy**:
- Prefer **SDXL base** style checkpoints known to work on 8–12GB VRAM for inference.
- Avoid “monster” merged models if they regularly OOM at target resolutions.

### LoRAs
**Allowed sources**:
- CivitAI
- HF

**Policy**:
- Maintain a **curated LoRA catalog per category**:
  - `product-photography`
  - `lifestyle`
  - `brand-style`
  - `typography`
  - `UI-anchoring`
- Store each LoRA with:
  - recommended weight range
  - trigger words
  - example renders

### ControlNet / preprocessors
**Allowed sources**:
- HF / official repos

**Policy**:
- Keep only what you use:
  - canny, depth, lineart, tile are the usual workhorses.

### IP-Adapter models
**Policy**:
- Keep “one good” SDXL IP-Adapter setup first.
- Version changes can shift aesthetics; pin carefully.

### Video models (Wan2.1)
**Policy**:
- Prefer Wan2.1 **1.3B** for RTX 3080 10GB.
- Treat video as a separate “capability lane” with separate manifests.

---

## 3) License rules (practical)

### Required fields per asset
Each model/LoRA must have:
- `license_id` (string)
- `license_url`
- `commercial_allowed` (boolean)
- `attribution_required` (boolean)
- `notes`

### Hard blockers
Do **not** use assets when:
- license explicitly forbids commercial use
- license is unknown / missing
- the source forbids redistribution and you can’t ensure internal-only use

### Suggested approach for CivitAI assets
- Read the model page license/permissions.
- Store a copy of the license text/screenshot in:
  - `marketing/model-manifests/licenses/<slug>/`

---

## 4) Version pinning, checksums, rollback

### Manifest format (YAML)
Example: `marketing/model-manifests/sdxl_base_1.0.yaml`
```yaml
id: sdxl-base-1.0
kind: checkpoint
filename: sdxl_base_1.0.safetensors
upstream:
  source: huggingface
  url: https://huggingface.co/...
license:
  id: stabilityai-community
  url: https://...
  commercial_allowed: true
hashes:
  sha256: "<sha256>"
install:
  target_subdir: checkpoints
  target_path_windows: "D:/ai/models/checkpoints/sdxl_base_1.0.safetensors"
notes:
  vram_profile: "~8-12GB inference @1024 with fp16 (batch1); refiner may exceed 10GB"
```

### Hash policy
- Always compute and store **SHA256**.
- The pipeline should refuse to run if a referenced file hash mismatches.

### Rollback policy
- Never overwrite an existing file with the same name.
- Use semantic suffixes:
  - `modelname_v1.safetensors`, `modelname_v2.safetensors`
- Keep a `latest` pointer only as a symlink/alias in your manifest, not as a file replacement.

---

## 5) VRAM guidance (RTX 3080 10GB)

### SDXL (images)
- SDXL **base-only** at 1024 typically fits around the 8–12GB region depending on workflow, precision, and extra modules.
- Adding **refiner**, heavy ControlNets, multiple LoRAs, high batch sizes, or large upscales can exceed 10GB.

**Operational rules**:
- Default to **batch=1**.
- Prefer:
  - fewer ControlNet stacks simultaneously
  - smaller preview renders first (e.g., 832×1216 / 768×1344) → upscale only for finalists
- If OOM occurs:
  - reduce resolution
  - reduce ControlNet count/weight
  - disable refiner
  - switch to a lighter VAE or offload components if available

### Wan2.1 (video)
- Reports/benchmarks commonly indicate Wan2.1 **1.3B** runs around ~8GB VRAM baseline; RTX 3080 10GB is viable for conservative settings.

**Operational rules**:
- Start with 480p and short durations.
- Avoid parallel video jobs.
- Consider CPU offload / quantized variants only if you must, and document the quality/perf tradeoff.

---

## 6) Model acquisition workflow (repeatable)

### Step 1 — Request
Create a request file:
- `marketing/model-requests/<date>_<asset>.md`
Include:
- intended use case (static ad, UI-anchored, lifestyle, video)
- expected license class
- why it’s needed

### Step 2 — Review
Approve only if:
- license OK
- VRAM profile plausible
- adds unique capability (not redundant)

### Step 3 — Install
- Download to a staging folder
- Compute sha256
- Create manifest
- Move into final ComfyUI models folder

### Step 4 — Validate
- Run a small “smoke workflow” that loads the model and generates 1 output.

### Step 5 — Promote
- Add to “night run allowed set” (see below)

---

## 7) Allowed set for night runs (curation)
Night runs should use only assets in:
- `marketing/model-manifests/allowed/`

Rationale: avoids nightly surprises from experimental downloads.

---

## 8) Deletion / cleanup policy
- Never delete approved/published assets.
- Models:
  - If deprecated, mark `status: deprecated` in manifest.
  - Keep for 30–90 days for rollback.
- If disk pressure:
  - archive deprecated models to cold storage.

---

## 9) Auditing & compliance
For every approved creative, store:
- workflow version
- model/LoRA ids + hashes
- seed
- prompt text

This is what makes “unlimited iteration” safe and defensible.

---

## References (high-level)
- ComfyUI automation relies on stable, pinned model files; hash/manifest-based pinning prevents silent drift.
- Wan2.1 public docs/benchmarks indicate the 1.3B model is the practical target for 10GB GPUs.
