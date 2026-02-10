# ComfyUI on Windows (RTX 3080 10GB) via Docker — concrete deployment plan

Target node: **Windows PC 192.168.100.155** (RTX 3080 10GB). Goal: run **ComfyUI** reliably with GPU acceleration, with reproducible commands and safe networking defaults.

## Key references (critical)
- Docker Desktop GPU support (WSL2 backend): https://docs.docker.com/desktop/features/gpu/
- Docker blog: WSL2 GPU support for Docker Desktop on NVIDIA GPUs: https://www.docker.com/blog/wsl-2-gpu-support-for-docker-desktop-on-nvidia-gpus/
- NVIDIA CUDA on WSL user guide (driver/WSL GPU-PV prerequisites): https://docs.nvidia.com/cuda/wsl-user-guide/index.html
- ComfyUI system requirements (VRAM guidance): https://docs.comfy.org/installation/system_requirements
- Example ComfyUI NVIDIA-focused docker images:
  - ashleykleynhans/comfyui-docker: https://github.com/ashleykleynhans/comfyui-docker
  - mmartial/ComfyUI-Nvidia-Docker: https://github.com/mmartial/ComfyUI-Nvidia-Docker

---

## Architecture A (recommended): Docker Desktop on Windows (WSL2 backend) + GPU-PV

### Why this is best-practice on Windows
- Docker Desktop integrates with WSL2 and supports NVIDIA GPU access for Linux containers using **GPU Paravirtualization (GPU-PV)**. For most users, you install **NVIDIA Windows driver + Docker Desktop** and then run containers with `--gpus` (no separate toolkit on Windows host required for Docker Desktop’s WSL integration). See Docker docs: https://docs.docker.com/desktop/features/gpu/

### A.0 Prerequisites checklist
1. **Windows 10/11** with WSL2 available.
2. **Latest NVIDIA GeForce driver** that supports CUDA on WSL.
   - Verify on Windows PowerShell:
     - `nvidia-smi`
3. **WSL2 updated**:
   - PowerShell (Admin):
     - `wsl --update`
     - `wsl --shutdown`
4. **Docker Desktop** installed and configured for WSL2 backend.
   - In Docker Desktop: Settings → General: “Use the WSL 2 based engine”.
   - Settings → Resources → WSL Integration: enable your Ubuntu distro.

### A.1 GPU verification (before ComfyUI)
Run this from **Windows PowerShell** or inside **WSL2** (where Docker CLI is available). The point is: confirm the container sees the GPU.

```powershell
docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi
```

Expected: it prints the RTX 3080 and driver/CUDA versions.

If it fails:
- Check Docker Desktop version and that WSL2 backend is enabled (Docker docs above).
- Check NVIDIA driver supports WSL2 (NVIDIA WSL user guide above).

### A.2 Choose a ComfyUI image
Two solid, widely used options:

**Option 1: ashleykleynhans/comfyui-docker** (simple run/compose patterns)
- Repo: https://github.com/ashleykleynhans/comfyui-docker

**Option 2: mmartial/ComfyUI-Nvidia-Docker** (multi-tag CUDA/Ubuntu variants)
- Repo: https://github.com/mmartial/ComfyUI-Nvidia-Docker

> Pick one image and standardize; don’t mix images for the same persistent volumes unless you know the filesystem expectations.

### A.3 Recommended directory strategy (WSL filesystem for performance)
Windows bind-mounts can be slower; best practice is to keep heavy model I/O inside the WSL2 Linux filesystem.

Inside your WSL distro:
```bash
mkdir -p ~/comfyui/{storage,models,output,input,custom_nodes}
```

Suggested semantics:
- `~/comfyui/models` → checkpoints/vae/loras/controlnet
- `~/comfyui/output` → generated images
- `~/comfyui/input` → source images
- `~/comfyui/custom_nodes` → custom nodes
- `~/comfyui/storage` → if the image expects a unified folder (ai-dock style)

### A.4 Docker run (safe default: localhost only)
This binds ComfyUI UI/API to **127.0.0.1** on the Windows host (safe).

Example using an image that exposes 8188:

```bash
docker run -d \
  --name comfyui \
  --gpus all \
  -p 127.0.0.1:8188:8188 \
  -v $HOME/comfyui/models:/workspace/ComfyUI/models \
  -v $HOME/comfyui/output:/workspace/ComfyUI/output \
  -v $HOME/comfyui/input:/workspace/ComfyUI/input \
  -v $HOME/comfyui/custom_nodes:/workspace/ComfyUI/custom_nodes \
  --restart unless-stopped \
  ghcr.io/mmartial/comfyui-nvidia-docker/ubuntu24_cuda12.8:latest
```

Notes:
- Path conventions vary by image. Adjust `/workspace/ComfyUI/...` according to the image documentation.
- If the image uses `/data` or `/workspace/storage`, map accordingly.

### A.5 Docker Compose (recommended for reproducibility)
Create `docker-compose.yml` in `~/comfyui/` within WSL2:

```yaml
services:
  comfyui:
    image: ghcr.io/mmartial/comfyui-nvidia-docker/ubuntu24_cuda12.8:latest
    container_name: comfyui
    restart: unless-stopped
    ports:
      - "127.0.0.1:8188:8188"
    volumes:
      - ./models:/workspace/ComfyUI/models
      - ./output:/workspace/ComfyUI/output
      - ./input:/workspace/ComfyUI/input
      - ./custom_nodes:/workspace/ComfyUI/custom_nodes
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
```

Run:
```bash
cd ~/comfyui
docker compose up -d
```

GPU sanity check inside container:
```bash
docker exec -it comfyui nvidia-smi
```

### A.6 LAN access (optional; be explicit about security)
If you need other machines to reach ComfyUI at `http://192.168.100.155:8188`:

1) Change port binding:
- Compose: `"0.0.0.0:8188:8188"`
- Or docker run: `-p 0.0.0.0:8188:8188`

2) Add Windows Firewall rule to allow TCP 8188 **only from LAN** (recommended), not from “Any”.

3) If exposing beyond LAN (not recommended): put it behind an authenticated reverse proxy (e.g., Cloudflare Tunnel + Access) rather than raw port-forwarding.

---

## Architecture B: Run ComfyUI inside WSL2 Ubuntu (GPU passthrough), optional Docker-in-WSL

### Why this exists
- You may prefer managing everything inside Linux (WSL2) with native Linux tooling.
- Good if you want to keep files under Linux paths and avoid Windows path quirks.

### B.0 Prerequisites checklist
1) Same **Windows + NVIDIA WSL-compatible driver** requirements as Architecture A (NVIDIA WSL guide).
2) Install a WSL2 distro (Ubuntu 22.04/24.04).
3) Update WSL kernel:
```powershell
wsl --update
wsl --shutdown
```

### B.1 Verify GPU visible inside WSL (no Docker yet)
Inside WSL:
```bash
nvidia-smi
```

Expected: shows RTX 3080. If `nvidia-smi` is missing, install the user-space utilities inside WSL:
```bash
sudo apt update
sudo apt install -y nvidia-utils-535
```
(Exact package version may differ; use `apt-cache search nvidia-utils`.)

### B.2 Option B1 (simplest): run ComfyUI natively in WSL (no Docker)
This is often the fastest path to first image, but less “containerized/reproducible”.

High-level steps:
```bash
sudo apt update
sudo apt install -y git python3-venv python3-pip

mkdir -p ~/comfyui-native && cd ~/comfyui-native

git clone https://github.com/comfyanonymous/ComfyUI.git
cd ComfyUI

python3 -m venv .venv
source .venv/bin/activate
pip install -U pip
pip install -r requirements.txt

# Start (bind localhost by default)
python main.py --listen 127.0.0.1 --port 8188
```

### B.3 Option B2: Docker Engine inside WSL (Docker-in-WSL)
Only do this if you intentionally want “Docker managed from inside WSL without Docker Desktop”.

- Install Docker Engine in WSL (per Docker Linux docs).
- Install NVIDIA Container Toolkit in WSL (Linux-side) to get `--gpus all` working.
  - NVIDIA toolkit install guide: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html

GPU test:
```bash
docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi
```

Then deploy ComfyUI container similarly to Architecture A.

### B.4 Networking notes (WSL)
- If you bind ComfyUI to `127.0.0.1`, it’s reachable from Windows host at `http://localhost:8188`.
- LAN reachability can be trickier depending on WSL networking mode; prefer Architecture A if you need stable LAN exposure.

---

## VRAM/performance guidance for RTX 3080 10GB

Source baseline: ComfyUI system requirements: https://docs.comfy.org/installation/system_requirements

### What fits well in 10GB
- **SD 1.5** (512px) workflows: very comfortable.
- **SDXL**: generally workable at 1024px with sensible settings; 10GB is near the practical minimum for heavier graphs.

### Recommended settings/techniques (to avoid OOM)
- Keep batch size at **1** for SDXL on 10GB.
- Prefer **FP16** weights (default for most setups).
- Enable memory-saving features when available:
  - **xFormers** attention (often included in curated images; otherwise enable/ install).
  - **VAE tiling** / tiled decode for large images.
  - Reduce resolution during latent steps; upscale afterward.
- Avoid stacking too many ControlNet/adapter nodes simultaneously.
- Keep an eye on VRAM using `nvidia-smi -l 1` while generating.

### Practical “known-good” starting point
- SDXL base at 1024×1024
- Steps: 20–30
- Sampler: DPM++ 2M Karras (common)
- CFG: 4–7
- Batch: 1
- Upscale with a second pass if needed.

---

## Operational tips
- Pin image tags (avoid `latest`) once stable.
- Persist volumes (models/output/custom_nodes) so container upgrades don’t wipe state.
- Back up:
  - `models/` (large; maybe keep on separate disk)
  - `custom_nodes/`
  - workflows JSON exports
- Prefer keeping models on SSD/NVMe.

---

## Recommended path + estimate

**Recommended path:** Architecture **A** (Docker Desktop + WSL2 backend) with a known maintained ComfyUI NVIDIA image (mmartial or ashleykleynhans). Bind to `127.0.0.1` by default; only open to LAN if you must and firewall it.

**Time to first image (rough):**
- If prerequisites already installed (WSL2 + Docker Desktop + NVIDIA driver): **30–60 minutes** (mostly pulling images + downloading models).
- From scratch (install everything): **1.5–3 hours** depending on downloads.
