# Oh-My-OpenCode local — secure SSH-based remote dev environment

A self-hosted Docker setup for running **OpenCode with Oh-My-OpenCode harness**, accessible via **SSH** (with dev web UI for Vite). Features:

- **SSH access** to dev container with all coding tools
- **Vite dev server frontend** exposed via reverse proxy with Basic Auth (port 5173)
- **Multi-agent orchestration** (via Oh-My-OpenCode)
- **Multi-Antigravity and Gemini accounts support** (via opencode-antigravity-auth)
- **spec-kit** support for Spec-Driven Development
- **Ralph Wiggum Autonomous Loop** for AI coding
- Optional **Cloudflare Tunnel** for public access without opening inbound ports

> Goal: run on a home **PC/Mac** (Docker Desktop), connect via SSH, and expose only the Vite dev frontend for testing.

---

## Security principles

1. **Vite frontend only** — exposed with Basic Auth for development testing
2. **Non-root containers** — all containers run as non-root user (`dev`)
3. **Minimal attack surface** — only SSH and Vite frontend are exposed

---

## Repository layout

```text
.
├── .devcontainer/
│   └── devcontainer.json
├── .env.example
├── .gitignore
├── Caddyfile
├── docker-compose.yaml
├── Dockerfile
├── README.md
├── dotfiles/                  # Editor configs (tracked in git)
│   └── nvim/                  # Neovim config (run scripts/copy_nvim_config.sh)
├── opencode_config/           # Your config files (gitignored, contains secrets)
│   ├── opencode.json
│   ├── oh-my-opencode.json
│   └── auth.json
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

### Recommended
- A domain in Cloudflare with **Cloudflare Zero Trust** (for global SSH access and Vite frontend via **Cloudflare Tunnel** + **Cloudflare Access** MFA/SSO)

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

### Generate a Caddy password hash (for Vite frontend)

```bash
docker run --rm caddy:2 caddy hash-password --plaintext 'YOUR_STRONG_PASSWORD'
```

Put the result into `.env`:

```bash
BASIC_AUTH_USER=aleksei
BASIC_AUTH_HASH=$2a$14$...paste_hash_here...
```

---

## 2) Build and run

```bash
docker compose up -d --build
```

### Access

* **SSH:** `ssh -p 2222 dev@localhost`
* **Vite frontend:** http://localhost:8080 (requires Basic Auth)

Stop:

```bash
docker compose down
```

---

## 3) SSH Access

### Local SSH Access

```bash
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

### SSH via Cloudflare Tunnel (Remote Access)

1. **Add SSH hostname to your tunnel** in Cloudflare Zero Trust Dashboard:
   * **Subdomain:** `ssh`
   * **Domain:** `yourdomain.com`
   * **Service Type:** `SSH`
   * **URL:** `ohmyopencode:22`

2. **Protect with Cloudflare Access** (recommended)

3. **Configure SSH client:**
   ```
   Host ssh.yourdomain.com
       HostName ssh.yourdomain.com
       User dev
       IdentityFile ~/.ssh/id_ed25519
       ProxyCommand cloudflared access ssh --hostname %h
   ```

4. **Connect:** `ssh ssh.yourdomain.com`

---

## 4) Set up Cloudflare Tunnel (recommended for global access)

This allows you to access SSH and the Vite frontend from anywhere without opening inbound ports.

### Step 1: Create the Tunnel

1. Log in to the [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)
2. Navigate to **Networks** → **Tunnels**
3. Click **Add a Tunnel** (or **Create a tunnel**)
4. Choose **Cloudflared** and click **Next**
5. Enter a **Tunnel name** (e.g., `dev-server`) and click **Save tunnel**

### Step 2: Get the Token

1. Under **Choose your environment**, select **Docker**
2. Copy only the **token string** found after `--token` (long base64 string)
3. Add to your `.env`:
   ```bash
   CF_TUNNEL_TOKEN=your_copied_token_here
   ```

### Step 3: Configure Public Hostnames

In the tunnel settings, go to **Public Hostname** tab and add:

**For Vite frontend (dev web UI):**
* **Subdomain:** `dev` (or `code`, `app`, etc.)
* **Domain:** `yourdomain.com`
* **Path:** (leave empty)
* **Service Type:** `HTTP`
* **URL:** `proxy:80`

**For SSH access:**
* **Subdomain:** `ssh`
* **Domain:** `yourdomain.com`
* **Path:** (leave empty)
* **Service Type:** `SSH`
* **URL:** `ohmyopencode:22`

### Step 4: Protect with Cloudflare Access (strongly recommended)

1. Go to **Access** → **Applications** → **Add an application**
2. Select **Self-hosted**
3. Add both hostnames (`dev.yourdomain.com` and `ssh.yourdomain.com`)
4. Create a policy requiring your email or identity provider
5. Enable MFA for additional security

### Step 5: Start the Stack

```bash
docker compose --profile tunnel up -d --build
```

### Step 6: Access Globally

* **Vite frontend:** https://dev.yourdomain.com (with Basic Auth + Cloudflare Access)
* **SSH:** `ssh ssh.yourdomain.com` (requires `cloudflared` on client, see Section 3)

---

## 5) Using it day-to-day

### Working via SSH

1. Connect: `ssh opencode-local`
2. Work in `/workspace` (your repo is mounted there)
3. Run OpenCode CLI, use neovim, or any terminal tools

### Running the Vite dev server

From SSH:
```bash
cd /workspace/project
pnpm install
pnpm dev --host 0.0.0.0
```

The Vite frontend is now accessible at http://localhost:8080 (with Basic Auth).

### Neovim and tmux

The container includes **neovim** (nightly) and **tmux** pre-installed.

**Copy your local nvim config into the project:**
```bash
./scripts/copy_nvim_config.sh
docker compose up -d --build
```

**Using tmux:**
```bash
ssh opencode-local
tmux new -s dev
nvim .
```

### Ralph Wiggum Autonomous Loop

```bash
./scripts/ralph.sh <iterations>
```

Requires `PLAN.txt` and `RALPH_PROGRESS.txt` in `/workspace/project/`.

---

## 6) VS Code Dev Container support

Open the repo in VS Code and run:

* "Dev Containers: Reopen in Container"

This uses `.devcontainer/devcontainer.json` and attaches to the `devcontainer` service.

---

## Configuration notes

### Non-root containers

* All containers run as user `dev` from the Dockerfile.
* Proxy (Caddy) listens on port `80` inside its container.

### Permissions for running shell commands

This repo initializes OpenCode config with:

* `"permission": { "bash": "ask" }`

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
* Check proxy logs: `docker compose logs -f proxy`

### Basic auth doesn't work

* Confirm the hash is the output of `caddy hash-password`
* Verify `.env` is loaded: `docker compose config | grep BASIC_AUTH`

---

## Updating

```bash
git pull
docker compose up -d --build
```

---

## References

* OpenCode CLI: [https://opencode.ai/docs/cli/](https://opencode.ai/docs/cli/)
* Oh-My-OpenCode (npm): [https://www.npmjs.com/package/oh-my-opencode](https://www.npmjs.com/package/oh-my-opencode)
* Caddy basic_auth: [https://caddyserver.com/docs/caddyfile/directives/basic_auth](https://caddyserver.com/docs/caddyfile/directives/basic_auth)
* Cloudflare Tunnel: [https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
* Cloudflare SSH via Tunnel: [https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/use-cases/ssh/](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/use-cases/ssh/)
