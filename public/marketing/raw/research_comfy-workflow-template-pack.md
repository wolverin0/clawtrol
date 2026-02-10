# ComfyUI Workflow Template Pack (v1)

Goal: a small, reusable set of **6 workflows** that can be called via ComfyUI API for nightly batch generation + scoring + Telegram approval.

Each workflow below is described in:
- **Purpose / when to use**
- **Inputs** (what n8n injects)
- **Core nodes** (recommended building blocks)
- **Key parameters to sweep**
- **Outputs**

> Implementation note: export each as **ComfyUI API JSON** and keep versions in `marketing/comfy/workflows/<template_id>/workflow_vN.json`.

---

## Common conventions across templates

### Standard inputs (n8n → Comfy)
- `positive_prompt`
- `negative_prompt`
- `seed`
- `width`, `height`
- `steps`, `cfg`, `sampler_name`
- `model_checkpoint`
- `vae`
- `lora_list[]` with `(path, weight)`
- Optional per-template:
  - `init_image` / `mask`
  - `ui_screenshot`
  - `control_image_*`
  - `ipadapter_ref_image`

### Standard outputs
- `output_image` (PNG)
- `preview_image` (JPG, smaller)
- `params.json` sidecar

### Recommended node families
- **Loaders**: CheckpointLoaderSimple, VAELoader, CLIPTextEncode
- **LoRA**: LoraLoader (or equivalent)
- **Sampling**: KSampler
- **Control**: ControlNetLoader + ApplyControlNet
- **Reference**: IP-Adapter nodes (SDXL-compatible)
- **Inpaint**: Inpaint conditioning / mask ops
- **Upscale**: ESRGAN/4x-UltraSharp or SDXL tile upscale workflow
- **Post**: ImageComposite/Overlay, ColorMatch (if available), SaveImage

---

## Template 1 — Static Ad (txt2img) “Clean Studio”

### Purpose
Generate clean, high-contrast product-centric ads with room for text and CTA.

### Best for
- New product announcements
- Price/offer tiles
- Fast volume generation

### Inputs
- product name, benefit angle → positive prompt
- brand colors (optional) → prompt tokens / palette constraints
- output formats: 1:1, 4:5, 9:16

### Core nodes
1. Load SDXL checkpoint
2. Positive/negative text encode
3. KSampler (txt2img)
4. (Optional) Simple background/gradient generator or “studio sweep” prompt
5. SaveImage

### Sweeps
- Steps: 20–30
- CFG: 4–7
- Sampler: DPM++ 2M Karras vs Euler a
- LoRA on/off + weights 0.4/0.7/1.0

### Output
- 1–4 images per seed

---

## Template 2 — Carousel Slide Generator (layout-consistent)

### Purpose
Produce 3–5 slides with consistent style and consistent typography space.

### Approach
Two-phase generation:
1) Generate a **style keyframe** (hero slide) via txt2img.
2) Generate additional slides via **img2img** with low denoise to preserve style.

### Inputs
- slide_index (1..N)
- headline/subheadline per slide
- shared style prompt

### Core nodes
- Txt2Img branch for slide_1
- Img2Img branch for slide_2..N using slide_1 as init
- Denoise control (low)

### Sweeps
- Slide_1: broader exploration
- Slide_2..N: denoise 0.15–0.35

### Output
- `slide_01.png ... slide_05.png`

---

## Template 3 — UI-Anchored Product Placement (screenshot → stable UI)

### Purpose
Create ads where a **real UI screenshot** (website/app/dashboard) stays intact and the product is inserted (or highlighted) without breaking layout.

### Best for
- “How it works” creatives
- UI feature callouts
- Before/after or “in the app” proof

### Inputs
- `ui_screenshot` (base)
- optional `ui_mask` (areas that must NOT change)
- product cutout image(s)
- copy: headline/sub

### Core nodes (recommended)
1. Load UI screenshot
2. (Optional) Resize/crop to target aspect ratio
3. **ControlNet** using:
   - canny/lineart from UI screenshot to preserve edges
   - depth (optional) if you want mild scene consistency
4. **IP-Adapter** with UI screenshot as reference (optional) to preserve UI style
5. Img2Img with **low denoise** (0.20–0.45)
6. Inpaint/Composite product into a defined region:
   - mask-based insert
   - optional shadow/highlight pass
7. SaveImage

### Critical sweeps
- Denoise: 0.20 / 0.30 / 0.40 / 0.50
- ControlNet weight: 0.55 / 0.75 / 0.90
- IP-Adapter weight: 0.50 / 0.70 / 0.85

### UI integrity scoring hooks
- Output a mask for UI region so scorer can compute SSIM vs base.

---

## Template 4 — Background Swap (product kept, scene changed)

### Purpose
Keep the product identity stable while swapping environments (studio → kitchen → office → outdoors).

### Inputs
- product image
- product mask (or auto-segment)
- background style prompt

### Core nodes
1. Load product image + mask
2. Inpaint background region (mask inverted)
3. ControlNet tile or depth optional
4. Optional color-match node to keep product colors true

### Sweeps
- Denoise: 0.35–0.65 (depends on how much change desired)
- Background style prompt variants

---

## Template 5 — Lifestyle Placement (reference-driven)

### Purpose
Generate “human/lifestyle” scenes that still match brand style and keep the product recognizable.

### Inputs
- product image
- 1–3 lifestyle reference images (style refs)
- constraints: avoid deformed hands/faces, keep product label readable

### Core nodes
1. Txt2Img or Img2Img depending on whether product is inserted or implied
2. **IP-Adapter** with lifestyle reference
3. Optional ControlNet pose for people (if you need consistent framing)
4. Inpaint for label clarity pass (small masked inpaint)

### Sweeps
- IP-Adapter weight 0.5–0.85
- LoRA weights 0.4–0.8
- Two-pass: generate scene → inpaint product label region for legibility

---

## Template 6 — I2V Reel Teaser (Wan2.1 1.3B)

### Purpose
Generate short motion snippets for reels/stories (attention grabbers), not full cinematic videos.

### Inputs
- `init_image` (approved still from Templates 1/3/5)
- motion prompt ("slow parallax", "subtle camera push-in")
- duration/frames, fps

### Core nodes (conceptual)
- Wan2.1 video model loader
- Conditioning from text + init frame
- Sampler/denoise for temporal generation
- Video assembly node (frames → mp4)

### Operational constraints (3080 10GB)
- Start at 480p and short duration.
- Avoid parallel video generations.

### Sweeps
- 3–8 seeds
- low/medium motion strengths

---

## Workflow versioning & templating strategy

### Template registry file
Maintain:
- `marketing/comfy/workflows/templates.json`
with:
- template_id
- current version
- input mapping (job JSON → node ids/fields)

### Parameter injection strategy (important)
When exporting workflow JSON, identify the node(s) to modify at runtime:
- CLIPTextEncode → `text`
- KSampler → `seed`, `steps`, `cfg`, `sampler_name`, `denoise`
- Loaders → checkpoint name/path
- LoRA loader nodes → enable/weight

Store a small `inputs_map.json` next to each workflow:
```json
{
  "positive_prompt": {"node_id": 6, "field": "text"},
  "negative_prompt": {"node_id": 7, "field": "text"},
  "seed": {"node_id": 12, "field": "seed"},
  "cfg": {"node_id": 12, "field": "cfg"}
}
```

This makes n8n injection deterministic even if the workflow graph grows.

---

## Quality guardrails (embed into workflows when possible)
- Always output a small preview JPG to speed Telegram review.
- For UI workflows: output the UI mask used so scoring can verify UI integrity.
- For lifestyle workflows: optionally run a second “label clarity inpaint” pass.

---

## Next additions (v2)
- Text-rendering layer (consistent typography) using:
  - vector overlay after generation (outside Comfy) or
  - dedicated text nodes if you accept AI text variability
- A dedicated “upscale finalists” workflow (tile + face/label preservation)

---

## References
- ComfyUI is commonly automated by exporting API workflows and posting them to `/prompt`, then retrieving results via `/history` and `/view`.
- Wan2.1 public docs/tutorials highlight the 1.3B path as the practical local option for consumer GPUs.
