# ComfyUI integration plan (OpenClaw / marketing pipeline)

Goal: make ComfyUI on **Windows node 192.168.100.155** usable as a **service** for automations (n8n, scripts) to generate marketing images consistently.

Key API references (community/official-ish):
- ComfyUI server comms routes (WebSocket + endpoints): https://docs.comfy.org/development/comfyui-server/comms_routes
- Example “host ComfyUI workflow via API” (practical): https://9elements.com/blog/hosting-a-comfyui-workflow-via-api/

> In practice, the essential endpoint is `POST /prompt` (submit workflow graph). Many examples derive from ComfyUI server routes and community guides.

---

## 1) Proposed shared folder layout

We need:
- A place where **Linux host (OpenClaw / n8n / dashboard)** can read/write assets (prompts, input images) and read results.
- A place where the **ComfyUI container/WSL** can read/write the same.

### Option 1 (preferred): SMB share hosted by Windows (PyApps) mounted on Linux + used by WSL
You already have `//192.168.100.155/PyApps` mounted on Linux as `/mnt/pyapps` (per infra map).

Create a dedicated folder:
- On Windows share: `PyApps\comfyui-data\`
- On Linux: `/mnt/pyapps/comfyui-data/`

Suggested structure:
```
/mnt/pyapps/comfyui-data/
  workflows/
    sdxl_text2img_api.json
    sd15_product_mock_api.json
  input/
    job-000123/
      source.png
      logo.svg
  output/
    job-000123/
      result_00001.png
      meta.json
  models/                 # optional (large); or keep models local to Windows SSD
  logs/
```

**Model storage note:**
- Models are huge; if Windows has a fast SSD, keep `models/` locally on Windows/WSL filesystem for performance.
- Only put `models/` on SMB if you accept slower I/O.

### Option 2: Keep everything in WSL filesystem and sync outputs back
- Store models + outputs under `~/comfyui/...` in WSL.
- A small sync step copies only final outputs to `/mnt/pyapps/...` or uploads them directly to wherever marketing pipeline needs.

---

## 2) Service exposure & security

### Safe default (recommended)
- Expose ComfyUI to **Windows localhost only**:
  - Docker port mapping: `127.0.0.1:8188:8188`

Then automations run on the same machine (Windows/WSL).

### If Linux host (192.168.100.186) must call it directly
- Bind to LAN: `0.0.0.0:8188:8188`
- Add Windows Firewall rule allowing **TCP 8188 only from 192.168.100.186** (or the LAN CIDR you control).
- Do **not** expose 8188 to the Internet.

Optional hardening:
- Put a reverse proxy in front (Caddy/Nginx) with basic auth + IP allowlist.
- Or use Cloudflare Tunnel + Access if you ever need remote access.

---

## 3) How to generate images via API

### 3.1 Workflow export (one-time per workflow)
In the ComfyUI UI:
- Build the workflow.
- Use **Save (API Format)**.
- Store under `/mnt/pyapps/comfyui-data/workflows/<name>.json`.

This JSON is what you send in `prompt`.

### 3.2 Minimal API request example (curl)
Assuming ComfyUI reachable at `http://192.168.100.155:8188` (LAN) or `http://localhost:8188` (local):

```bash
curl -s http://192.168.100.155:8188/prompt \
  -H 'Content-Type: application/json' \
  -d @/mnt/pyapps/comfyui-data/workflows/sdxl_text2img_api.json
```

Typical request body shape:
```json
{
  "prompt": {
    "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "sd_xl_base_1.0.safetensors"}},
    "2": {"class_type": "CLIPTextEncode", "inputs": {"text": "a product photo...", "clip": ["10", 0]}},
    "3": {"class_type": "EmptyLatentImage", "inputs": {"width": 1024, "height": 1024, "batch_size": 1}},
    "4": {"class_type": "KSampler", "inputs": {"seed": 1, "steps": 25, "cfg": 6, "sampler_name": "dpmpp_2m", "scheduler": "karras", "model": ["1", 0], "positive": ["2", 0], "latent_image": ["3", 0]}},
    "5": {"class_type": "VAEDecode", "inputs": {"samples": ["4", 0], "vae": ["1", 2]}},
    "6": {"class_type": "SaveImage", "inputs": {"images": ["5", 0], "filename_prefix": "job-000123"}}
  },
  "client_id": "marketing-pipeline"
}
```

Response includes a `prompt_id`.

### 3.3 Getting results
Two common approaches:

1) Poll history:
- `GET /history/{prompt_id}`

2) Use WebSocket for progress:
- `ws://<host>:8188/ws?clientId=<client_id>`

Then fetch files via `/view` or just read from the output directory volume if you mounted it.

Practical guide: https://9elements.com/blog/hosting-a-comfyui-workflow-via-api/

---

## 4) n8n integration (recommended pattern)

### Where n8n runs
In your infra, n8n is on the Linux host (192.168.100.186). So you have two choices:

A) Allow n8n to call ComfyUI on Windows over LAN (firewall-restricted).
B) Run a small “bridge” script on Windows/WSL that n8n triggers (e.g., via SSH) so ComfyUI stays localhost-only.

**Recommended security pattern:** (B) SSH-triggered local call.

### Pattern B: n8n → SSH (WSL) → curl localhost:8188
1) n8n workflow:
- Node 1: Create job id (e.g., timestamp)
- Node 2: Write workflow JSON with the prompt injected (Function node)
- Node 3: SSH node to Windows WSL (port 2222) to:
  - save workflow json under shared folder
  - `curl http://localhost:8188/prompt ...`

Example SSH command (conceptual):
```bash
JOB=job-$(date +%Y%m%d-%H%M%S)
WF=/mnt/pyapps/comfyui-data/workflows/sdxl_text2img_api.json

curl -s http://localhost:8188/prompt -H 'Content-Type: application/json' -d @${WF}
```

Then:
- Poll `/history/<prompt_id>` until outputs exist.
- Copy resulting images to `/mnt/pyapps/comfyui-data/output/${JOB}/`.

### Pattern A: n8n HTTP Request node directly to Windows
If you open LAN access:
- HTTP Request node:
  - Method: POST
  - URL: `http://192.168.100.155:8188/prompt`
  - Body: JSON (the workflow)

Hard requirement: Windows Firewall restrict access to only the n8n host.

---

## 5) Operational conventions (so marketing stays sane)

### Job IDs + metadata
For each generation job, write a `meta.json` alongside outputs:
```json
{
  "job_id": "job-000123",
  "workflow": "sdxl_text2img_api.json",
  "prompt": "...",
  "negative_prompt": "...",
  "seed": 123456,
  "created_at": "2026-02-09T20:45:00-03:00",
  "outputs": ["result_00001.png"],
  "comfyui_host": "192.168.100.155:8188"
}
```

### Model pinning
- Standardize on 1–2 base models (e.g., SDXL base + SD 1.5 fallback).
- Keep a single folder naming convention so workflows don’t break when moving between machines.

### Volume mapping contract
Decide and document where ComfyUI writes outputs:
- If container maps to `/workspace/ComfyUI/output`, ensure it’s mounted to a known host folder (WSL or SMB).

---

## Recommended integration approach (summary)

1) Deploy ComfyUI on Windows via Docker Desktop (Architecture A).
2) Keep ComfyUI bound to `127.0.0.1:8188`.
3) Use n8n → SSH into WSL on Windows (port 2222) to submit workflows to `http://localhost:8188/prompt`.
4) Persist outputs into `/mnt/pyapps/comfyui-data/output/...` so Linux-side marketing pipeline can pick them up.

This keeps the GPU service private by default, while still fully automatable.
