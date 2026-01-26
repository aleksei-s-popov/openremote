# Oh-My-OpenCode local — secure SSH-based remote dev environment

A self-hosted Docker setup for running **OpenCode with Oh-My-OpenCode harness**
Features:

- **SSH access** to dev container with all coding tools (tmux, nvim)
- **Vite dev server frontend** exposed directly (port 5173)
- **Multi-agent orchestration** (via Oh-My-OpenCode)
- **Multi-Antigravity and Gemini accounts support** (via opencode-antigravity-auth)
- **Github Spec Kit** support for Spec-Driven Development
- **Ralph Wiggum Autonomous Loop** for /speckit.implement command
- Designed for use behind **Tailscale VPN** for secure remote access

> Goal: run on a home **PC/Mac** (Docker Desktop), connect from a laptop or phone via SSH through Tailscale VPN.

Feel free to fork and customize everything.

---

## Security principles

1. **Tailscale VPN** — all access is through your private Tailnet
2. **Non-root containers** — all containers run as non-root user (`dev`)
3. **Minimal attack surface** — only SSH and dev server ports exposed to host

---

## Repository layout

```text
.
├── .devcontainer/
│   └── devcontainer.json
├── .env.example
├── .gitignore
├── docker-compose.yaml
├── Dockerfile
├── README.md
├── dotfiles/                  # Editor configs (tracked in git)
│   └── nvim/                  # Neovim config (run scripts/copy_nvim_config.sh)
├── opencode_config/           # Your config files (gitignored, contains secrets)
├── opencode_config_example/   # Example configurations
├── scripts/
│   ├── entrypoint.sh
│   ├── copy_nvim_config.sh    # Copy local nvim config to dotfiles/
│   └── ralph.sh               # Ralph Wiggum autonomous loop
└── workspace/                 # Mounted into container at /workspace
```

---

## Prerequisites

### Required
- Docker (Docker Desktop on macOS)
- Tailscale installed on host machine

---

## 1) Clone and configure environment

```bash
git clone <YOUR_REPO_URL>
cd <YOUR_REPO_DIR>

cp .env.example .env
```

### Configure LLM Providers

**For Local LLMs (e.g., LM Studio):**
```bash
LLM_BASE_URL=http://YOUR_LOCAL_IP:1234/v1
LLM_MODEL=model-identifier-string
LLM_API_KEY=lm-studio
```

**For Cloud Providers:**
```bash
ANTHROPIC_API_KEY=sk-ant-...
GOOGLE_API_KEY=AIza...
OPENROUTER_API_KEY=sk-or-...
```

### Configure SSH Access (required)

Add your public key to `.env`:

```bash
SSH_PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... your@email.com"
```

**Multiple devices:** Separate keys with `|` (pipe):
```bash
SSH_PUBLIC_KEY="ssh-ed25519 AAAA... laptop|ssh-ed25519 BBBB... phone"
```

**Get your existing public key:**
```bash
cat ~/.ssh/id_ed25519.pub
```

### Copy local opencode config

If you want to copy your local opencode config with auth keys (for example for opencode-antigravity-auth) - copy them with

```bash
bash scripts/copy_opencode_config.sh
```

### Copy local nvim config

If you want to use your local nvim setup

```bash
bash scripts/copy_nvim_config.sh
```

---

## 2) Build and run

```bash
docker compose up -d --build
```

### Access

* **SSH:** `ssh -p 2222 dev@localhost`
* **Vite frontend:** http://localhost:5173 (requires running dev server in the container)
* **OpenCode web UI:** http://localhost:4096 (if enabled)

Stop:

```bash
docker compose down
```

---

## 3) SSH Access

### Local SSH Access

```bash
# if you recreated the container - you might want to clean local ssh keys
# ssh-keygen -R "[localhost]:2222"
ssh -p 2222 dev@localhost
```

**Using SSH config (recommended):**

Add to `~/.ssh/config`:
```
Host opencode-local
    HostName localhost
    Port 2222
    User dev
    IdentityFile ~/.ssh/id_ed25519
```

Then:
```bash
# ssh-keygen -R "[localhost]:2222"
ssh opencode-local
```

---

## 4) Remote Access via Tailscale

This setup is designed to run on a machine inside your Tailscale VPN.

### Install Tailscale on Host

1. Install: https://tailscale.com/download
2. Authenticate: `tailscale up`
3. Note your Tailscale IP: `tailscale ip -4`

### Access from Other Devices

Ensure your other devices (laptop, phone) are on the same Tailnet.

**SSH:** `ssh -p 2222 dev@<tailscale-ip>`
**Vite:** `http://<tailscale-ip>:5173`

### SSH Config for Remote Access

Add to `~/.ssh/config` on your laptop/other machines:

```
Host opencode
    HostName 100.x.x.x  # Your Tailscale IP
    Port 2222
    User dev
    IdentityFile ~/.ssh/id_ed25519
```

Then connect: `ssh opencode`

**With MagicDNS enabled:**
```
Host opencode
    HostName your-machine-name  # Your Tailscale MagicDNS hostname
    Port 2222
    User dev
    IdentityFile ~/.ssh/id_ed25519
```

---

## 5) Using it day-to-day

### Working via SSH

1. Connect: `ssh opencode-local` (local) or `ssh opencode` (remote via Tailscale)
2. Work in `/workspace/project` (your repo is mounted there)
3. Run OpenCode CLI, use neovim, or any terminal tools

### Running the Vite dev server

From SSH:
```bash
cd /workspace/project
# example for Vite project
# pnpm install
# pnpm dev --host 0.0.0.0
```

The Vite frontend is now accessible at:
- Local: http://localhost:5173
- Remote: http://<tailscale-ip>:5173

### Neovim and tmux

The container includes **neovim** (nightly) and **tmux** pre-installed.

**Copy your local nvim config into the project:**
```bash
./scripts/copy_nvim_config.sh
docker compose up -d --build
```

**Auto-starting tmux sessions:**

On container startup, a base tmux session `openremote` is automatically created with:
- `opencode` window: OpenCode web UI (port 4096)
- `tui` window: OpenCode TUI

If your project has a `session.yaml` in root (`/workspace/project/session.yaml`), it will also be loaded automatically. This allows project-specific tmux sessions.

Example project `session.yaml`:
```yaml
session_name: myproject
start_directory: /workspace/project
windows:
  - window_name: dev
    panes:
      - shell_command: pnpm dev --host 0.0.0.0
  - window_name: shell
    panes:
      - shell_command: bash
```

**Attaching to tmux sessions:**
```bash
ssh opencode-local
tmux ls                    # List all sessions
tmux attach -t openremote  # Attach to base session
```

### Ralph Wiggum Autonomous Loop with Spec Kit

https://speckit.org/

```bash
ssh opencode-local
cd /workspace/project

# Init Spec Kit
specify init . --ai opencode

# Establish project principles
opencode run "/speckit.constitution {your project's governing principles and development guidelines}"

# Create Specification
opencode run "/speckit.specify {describe what you want to build}"

# Create technical plans
opencode run "/speckit.plan {describe technical plan and spec}"

# Generate tasks
opencode run "/speckit.tasks"

# Execute tasks implementation within Ralph Wiggum loop
ralph.sh -i=<max-iterations>

# Repeat from /speckit.specify
```


**Optional Slack integration:**

If you want to get notifications on Ralph Wiggum iterations add Slack webhook URL to `RALPH_SLACK_WEBHOOK_URL` in `.env`

---

## 6) VS Code Dev Container support

Open the repo in VS Code and run:

* "Dev Containers: Reopen in Container"

This uses `.devcontainer/devcontainer.json` and attaches to the `devcontainer` service.

---

## Configuration notes

Feel free to fork and customize everything.

### Non-root containers

* All containers run as user `dev` from the Dockerfile.

### Permissions for running shell commands

This repo initializes OpenCode config with:

* `"permission": { "bash": "ask" }`

---

## Exposed Ports Summary

| Port | Service | Purpose |
|------|---------|---------|
| 2222 | SSH | Terminal access |
| 5173 | Vite | Dev server (`pnpm dev --host 0.0.0.0`) |
| 4096 | OpenCode | Web UI (optional) |

---

## Troubleshooting

### SSH connection refused

* Verify `SSH_PUBLIC_KEY` is set in `.env`
* Check if SSH server is running:
  ```bash
  docker compose exec ohmyopencode ps aux | grep sshd
  ```
* Check logs:
  ```bash
  docker compose logs ohmyopencode | grep -i ssh
  ```

### Vite frontend not loading

* Ensure Vite is running with `--host 0.0.0.0`
* Check container logs: `docker compose logs -f ohmyopencode`

---

## Updating

```bash
git pull
docker compose up -d --build
```

---

## License

This project is licensed under the terms of the MIT open source license. Please refer to the LICENSE file for the full terms.
---

## References

* OpenCode CLI: [https://opencode.ai/docs/cli/](https://opencode.ai/docs/cli/)
* Oh-My-OpenCode (npm): [https://www.npmjs.com/package/oh-my-opencode](https://www.npmjs.com/package/oh-my-opencode)
* Tailscale: [https://tailscale.com/](https://tailscale.com/)
* Tailscale Download: [https://tailscale.com/download](https://tailscale.com/download)
