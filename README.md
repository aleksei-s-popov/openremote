# Oh-My-OpenCode local — secure-ish "code from your phone" Docker setup

A self-hosted, **OpenCode server with the Oh-My-OpenCode harness**, pre-configured with the **Sisyphus orchestrator agent**, **Spec Kit** and **common language servers**, with web interface, SSH and Neovim. Plus:

- **Multi-agent orchestration** (via Oh-My-OpenCode)
- **Multi-Antigravity and Gemini accounts support** (via opencode-antigravity-auth) for multiple free tiers
- **spec-kit** support
- **Ralph Wiggum Autonomous Loop for AI Coding** support, integrated with **spec-kit**
- **Reverse proxy with HTTP Basic Auth** (Caddy)
- **SSH access** to container (local or via Cloudflare)
- Optional **web terminal** (`ttyd`)
- Optional **Cloudflare Tunnel** for public access without opening inbound ports
- Optional **web "stack manager"** (Dockge) *behind a separate auth gate* (with socket proxy for security)

> Goal: run on a home **PC/Mac** (Docker Desktop), connect to local model if needed and vibe code nonstop from a laptop or phone.

---

## Security principles (what this repo tries to enforce)

1. **No root in web-exposed app containers**
   - The OpenCode/Oh-My-OpenCode and web terminal containers run as a non-root user (`dev`).
   - The proxy container is also configured to run as non-root and listen on an unprivileged port.

2. **No direct container ports exposed except the proxy**
   - Only the proxy is published (or nothing is published if you use Cloudflare Tunnel).
   - The core services are on an internal Docker network only.

3. **Danger zone is opt-in**
   - Dockge (web UI to manage Docker Compose) is **disabled by default** and only enabled via a Compose profile.
   - Dockge uses a **socket-proxy** to avoid direct host-root access.

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
├── opencode_config/           # Your config files (copied into container)
│   ├── opencode.json
│   ├── oh-my-opencode.json
│   └── auth.json
├── opencode_config_example/   # Example configurations
├── scripts/
│   ├── entrypoint.sh
│   └── ralph.sh               # Ralph Wiggum autonomous loop
└── workspace/                 # Mounted into container at /workspace
```

---

## Prerequisites

### Required
- Docker (Docker Desktop on macOS)
- A domain in Cloudflare (recommended if you want global access)

### Recommended
- Cloudflare Zero Trust (for **Cloudflare Tunnel** + **Cloudflare Access** MFA/SSO)
- A dedicated machine user / token strategy for your AI provider keys (don't bake secrets into the image)

---

## 1) Clone and configure environment

```bash
git clone <YOUR_REPO_URL>
cd <YOUR_REPO_DIR>

cp .env.example .env
```

### Configure LLM Providers

This setup supports both local LLMs (via LM Studio, Ollama, etc.) and cloud providers (Anthropic, Gemini, OpenRouter).

Edit your `.env` file to set your API keys and endpoints:

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

### Configure SSH Access (optional)

To enable SSH access to the container, add your public key to `.env`:

```bash
SSH_PUBLIC_KEY="ssh-ed25519 AAAAC3... your@email.com"
```

You can get your public key with:
```bash
cat ~/.ssh/id_ed25519.pub
# or
cat ~/.ssh/id_rsa.pub
```

### Generate a Caddy password hash

Caddy uses **hashed** passwords for `basic_auth`.

```bash
docker run --rm caddy:2 caddy hash-password --plaintext 'YOUR_STRONG_PASSWORD'
```

Put the result into `.env`:

```bash
BASIC_AUTH_USER=aleksei
BASIC_AUTH_HASH=$2a$14$...paste_hash_here...
```

---

## 2) Build and run locally (no Cloudflare yet)

```bash
docker compose up -d --build
```

Open in your browser:

* Proxy (auth gate): [http://localhost:8080](http://localhost:8080)
* Oh-My-OpenCode is served at `/` (defaults to **Sisyphus** agent)
* Web terminal (optional): `/term/`

Stop:

```bash
docker compose down
```

---

## 3) SSH Access

The container exposes SSH on port 22. You can connect via SSH for a full terminal experience with your preferred editor (vim, nvim, etc.).

### Local SSH Access

If you're on the same network as the Docker host:

1. **Find the container's SSH port mapping:**
   ```bash
   docker compose ps ohmyopencode
   ```

   By default, port 22 is exposed. You may need to add a port mapping to `docker-compose.yaml`:
   ```yaml
   ohmyopencode:
     ports:
       - "2222:22"  # Map container port 22 to host port 2222
   ```

2. **Connect via SSH:**
   ```bash
   ssh -p 2222 dev@localhost
   ```

   Or if connecting from another machine on your network:
   ```bash
   ssh -p 2222 dev@<DOCKER_HOST_IP>
   ```

3. **Using SSH config (recommended):**

   Add to `~/.ssh/config`:
   ```
   Host opencode-local
       HostName localhost
       Port 2222
       User dev
       IdentityFile ~/.ssh/id_ed25519
   ```

   Then simply:
   ```bash
   ssh opencode-local
   ```

### SSH via Cloudflare Tunnel (Remote Access)

For SSH access from anywhere without exposing ports, use Cloudflare Tunnel with `cloudflared access`.

#### Step 1: Add SSH hostname to your tunnel

1. Go to [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)
2. Navigate to **Networks** → **Tunnels**
3. Find your tunnel and click **Edit**
4. Go to **Public Hostname** tab → **Add a public hostname**
5. Configure:
   * **Subdomain:** `ssh` (or `code-ssh`, etc.)
   * **Domain:** `yourdomain.com`
   * **Path:** (leave empty)
   * **Service Type:** `SSH`
   * **URL:** `ohmyopencode:22`
6. Click **Save hostname**

#### Step 2: Protect with Cloudflare Access

1. Go to **Access** → **Applications** → **Add an application**
2. Select **Self-hosted**
3. Configure:
   * **Application name:** `SSH Access`
   * **Subdomain:** `ssh`
   * **Domain:** `yourdomain.com`
4. Add a policy:
   * **Policy name:** `Allow Me`
   * **Action:** `Allow`
   * **Include:** Your email or identity provider
5. Save the application

#### Step 3: Install cloudflared on your client

**macOS:**
```bash
brew install cloudflared
```

**Linux:**
```bash
# Debian/Ubuntu
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o cloudflared.deb
sudo dpkg -i cloudflared.deb

# Or using the binary
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared
chmod +x cloudflared
sudo mv cloudflared /usr/local/bin/
```

**Windows:**
```powershell
winget install Cloudflare.cloudflared
```

#### Step 4: Configure SSH to use cloudflared

Add to your `~/.ssh/config`:

```
Host ssh.yourdomain.com
    HostName ssh.yourdomain.com
    User dev
    IdentityFile ~/.ssh/id_ed25519
    ProxyCommand cloudflared access ssh --hostname %h
```

#### Step 5: Connect

```bash
ssh ssh.yourdomain.com
```

The first time you connect:
1. `cloudflared` will open your browser for Cloudflare Access authentication
2. After authenticating, the SSH connection will establish
3. Subsequent connections may use cached credentials (depending on your Access policy session duration)

#### Alternative: Short-lived certificates (advanced)

For enhanced security, you can configure Cloudflare to issue short-lived SSH certificates instead of using your regular SSH keys:

1. In Zero Trust Dashboard, go to **Access** → **Service Auth** → **SSH**
2. Generate a CA for your application
3. Add the CA public key to `/etc/ssh/sshd_config` in the container
4. Configure `cloudflared` to request certificates

See [Cloudflare SSH documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/use-cases/ssh/) for details.

---

## 4) Set up Cloudflare Tunnel (recommended "anywhere access")

### Option A (recommended): Remote-managed tunnel using a token

1. **Create the Tunnel in Cloudflare Zero Trust:**
   * Log in to the [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/).
   * Navigate to **Networks** → **Tunnels**.
   * Click **Add a Tunnel** (or **Create a tunnel**).
   * Choose **Cloudflared** and click **Next**.
   * Enter a **Tunnel name** (e.g., `omo-server`) and click **Save tunnel**.

2. **Retrieve the Token:**
   * Under **Choose your environment**, select **Docker**.
   * Look for the command starting with `docker run...`.
   * **Copy only the token string** found after `--token` (it's a long base64 string).
   * Put this token into your `.env` file:
     ```bash
     CF_TUNNEL_TOKEN=your_copied_token_here
     ```

3. **Start the Tunnel:**
   * Run the following command to start the stack with the tunnel enabled:
     ```bash
     docker compose --profile tunnel up -d --build
     ```

4. **Configure Public Hostnames:**
   * Go back to your tunnel settings in Cloudflare (click **Next** or find your tunnel in the list and click **Edit**).
   * Go to the **Public Hostname** tab and add hostnames:

   **For Web UI:**
   * **Subdomain:** `code`
   * **Domain:** `yourdomain.com`
   * **Service Type:** `HTTP`
   * **URL:** `proxy:80`

   **For SSH (optional):**
   * **Subdomain:** `ssh`
   * **Domain:** `yourdomain.com`
   * **Service Type:** `SSH`
   * **URL:** `ohmyopencode:22`

Now you should be able to access:
* Web UI: [https://code.yourdomain.com/](https://code.yourdomain.com/)
* SSH: `ssh ssh.yourdomain.com` (with cloudflared proxy)

### Add Cloudflare Access (strongly recommended)

In **Zero Trust → Access → Applications**:

* Protect `code.yourdomain.com` and `ssh.yourdomain.com`
* Require MFA / your identity provider
* Optionally restrict by country, device posture, IP allowlist, etc.

> If you use Access, Basic Auth becomes a second layer, not your only gate.

---

## 5) Using it day-to-day

### Oh-My-OpenCode Web UI

* Go to `/` (root)
* Work inside `/workspace` (your repo is mounted there)
* Oh-My-OpenCode will use the configured language servers installed in the image.

### Web terminal (ttyd)

* Go to `/term/`
* You get a shell in the container as the non-root `dev` user.

### SSH access

* Connect via local SSH or Cloudflare tunnel (see section 3)
* Use your preferred editor (vim, nvim, etc.)
* Full terminal access as `dev` user

### Running dev server / tests

From the terminal:

```bash
cd /workspace
pnpm install
pnpm dev
```

If you want to reach your app dev server from your phone, you have two approaches:

1. Add another proxy route in `Caddyfile` to forward `/app/*` to your Vite dev server port
2. Or expose the Vite port through Cloudflare separately (less ideal)

### Ralph Wiggum Autonomous Loop

Run the autonomous AI coding loop:

```bash
./scripts/ralph.sh <iterations>
```

Requires `PLAN.txt` and `RALPH_PROGRESS.txt` files in `/workspace/project/`.

### Spec-Kit (Specify CLI) support

This image comes with [spec-kit](https://github.com/github/spec-kit) pre-installed via the `specify` CLI. It supports Spec-Driven Development (SDD) with OpenCode.

To initialize spec-kit in your project:
1. Open the web terminal.
2. Run: `specify init --ai opencode`
3. Follow the prompts.

This will create `.opencode/command/` with slash commands like `/speckit.constitution`, `/speckit.specify`, etc., which you can use directly in the OpenCode web UI.

---

## 6) VS Code Dev Container support

Open the repo in VS Code and run:

* "Dev Containers: Reopen in Container"

This uses `.devcontainer/devcontainer.json` and attaches to the `devcontainer` service.

---

## 7) "Recreate/redeploy from the web" (optional, risky)

### Dockge (disabled by default)

Dockge is convenient, but it mounts `/var/run/docker.sock` which is **effectively host-admin**.

Enable it only if:

* You also protect it with **Cloudflare Access** and a separate password, and
* You understand the risk.

Start Dockge:

```bash
docker compose --profile admin up -d
```

Then open:

* http(s)://<your-host>/dockge/

**Hard rule:** do not expose Dockge publicly without Cloudflare Access + strict restrictions.

---

## Configuration notes

### Non-root containers

* OpenCode/terminal run as user `dev` from the Dockerfile.
* Proxy (Caddy) listens on port `80` inside its container.

### CORS

If you keep everything behind the same origin (`https://code.yourdomain.com/`), you typically don't need custom CORS.
If you do, set:

```bash
OPENCODE_CORS=https://code.yourdomain.com
```

### Permissions for running shell commands

This repo initializes OpenCode config with:

* `"permission": { "bash": "ask" }`

That's intentional. You can relax it later, but "ask" is safer when exposed over the internet.

---

## Troubleshooting

### "I can't access files / permission denied"

On macOS Docker Desktop, make sure the repo folder is allowed in:

* Docker Desktop → Settings → Resources → File Sharing

### Cloudflare shows 502 / "Host error"

* Confirm `cloudflared` is on the same Docker network as `proxy`
* Confirm your Cloudflare "service" points to `http://proxy:80`
* Check logs:

```bash
docker compose logs -f cloudflared
docker compose logs -f proxy
```

### Basic auth doesn't work

* Confirm the hash is the output of `caddy hash-password`
* Confirm your `.env` is actually being loaded:

```bash
docker compose config | grep BASIC_AUTH -n
```

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

### Cloudflare SSH not working

* Verify the SSH hostname is configured in your tunnel
* Check that Cloudflare Access policy allows your identity
* Ensure `cloudflared` is installed and working:
  ```bash
  cloudflared --version
  cloudflared access ssh --hostname ssh.yourdomain.com --destination localhost:22
  ```

---

## Updating

Pull changes and rebuild:

```bash
git pull
docker compose up -d --build
```

---

## Security hardening ideas (recommended improvements)

If you want to make this more robust for a public GitHub repo:

1. **Prefer Cloudflare Access** over relying on Basic Auth alone.
2. **Disable the web terminal by default**

   * Keep it behind a Compose profile so users opt-in:

     * `docker compose --profile term up -d`
3. Add container hardening:

   * `security_opt: ["no-new-privileges:true"]`
   * `cap_drop: ["ALL"]`
   * `read_only: true` + `tmpfs: /tmp` (only if your app supports it)
4. Consider isolating build tooling

   * A "runner" container for compiling/testing separate from the web-exposed UI container.
5. Use an allowlist in Cloudflare Access (email domain, device posture, country, IP)
6. Add rate limiting / WAF rules in Cloudflare to reduce brute-force pressure.

---

## References (official docs)

* OpenCode CLI: [https://opencode.ai/docs/cli/](https://opencode.ai/docs/cli/)
* OpenCode Config: [https://opencode.ai/docs/config/](https://opencode.ai/docs/config/)
* OpenCode Plugins: [https://opencode.ai/docs/plugins/](https://opencode.ai/docs/plugins/)
* Oh-My-OpenCode (npm): [https://www.npmjs.com/package/oh-my-opencode](https://www.npmjs.com/package/oh-my-opencode)
* Caddy basic_auth: [https://caddyserver.com/docs/caddyfile/directives/basic_auth](https://caddyserver.com/docs/caddyfile/directives/basic_auth)
* Cloudflare Tunnel: [https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
* Cloudflare SSH via Tunnel: [https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/use-cases/ssh/](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/use-cases/ssh/)
* Cloudflare Access: [https://developers.cloudflare.com/cloudflare-one/policies/access/](https://developers.cloudflare.com/cloudflare-one/policies/access/)

---

## License

Pick a license that fits your intent (MIT is common for templates).

---

# Appendix: The "non-root proxy" image (proxy/Dockerfile)

This makes sure the proxy itself does not run as root and listens on port 80.

```dockerfile
FROM caddy:2-alpine

# Create non-root user
RUN addgroup -g 10001 caddyuser && adduser -D -H -u 10001 -G caddyuser caddyuser

# Prepare writable dirs for Caddy
RUN mkdir -p /data /config && chown -R 10001:10001 /data /config

USER 10001:10001
EXPOSE 80

CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
```

---

# Appendix: Proxy config note (Caddyfile)

Make sure your Caddyfile listens on `:80` (unprivileged port), e.g.:

```caddyfile
:80 {
  # ...
}
```

---

# Appendix: "What's the threat model here?"

This stack gives you "convenient remote dev" but it is not equivalent to a locked-down enterprise remote workstation.
Assume:

* If your credentials are stolen, attackers may run code in your repo environment.
* If you enable Dockge, compromise could lead to host takeover.

Use Cloudflare Access + MFA, avoid exposing Dockge, and keep the web terminal disabled unless you truly need it.