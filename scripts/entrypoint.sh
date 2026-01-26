#!/usr/bin/env bash
set -euo pipefail

# If running as root, start sshd and drop privileges
if [ "$(id -u)" = "0" ]; then
    echo "Starting SSH server..."
    mkdir -p /run/sshd
    
    # Export Docker env vars to /etc/environment so SSH sessions (pam_env) can see them
    # We only export specific variables defined in docker-compose.yaml
    printenv | grep -E '^(GITHUB_REPO_URL|GITHUB_TOKEN|LLM_MODEL|LLM_BASE_URL|LLM_API_KEY|OPENAI_BASE_URL|OPENAI_API_KEY|ANTHROPIC_API_KEY|GOOGLE_API_KEY|OPENROUTER_API_KEY|CONTEXT7_API_KEY|SSH_PUBLIC_KEY|RALPH_SLACK_WEBHOOK_URL)=' >> /etc/environment || true
    
    /usr/sbin/sshd
    
    # Re-exec the script as the 'dev' user
    echo "Switching to user 'dev'..."
    exec sudo -E -u dev HOME=/home/dev "$0" "$@"
fi

# Defaults
: "${OPENCODE_HOST:=0.0.0.0}"
: "${OPENCODE_PORT:=4096}"
: "${OPENCODE_CORS:=}"           # comma-separated list, e.g. "https://your.domain,https://another.domain"
: "${OPENCODE_WORKDIR:=/workspace}"
: "${SSH_PUBLIC_KEY:=}"

# Setup SSH access if key(s) provided
# Supports multiple keys separated by | (pipe) character
if [[ -n "${SSH_PUBLIC_KEY}" ]]; then
  echo "Setting up SSH authorized keys..."
  mkdir -p "${HOME}/.ssh"
  chmod 700 "${HOME}/.ssh"
  # Replace | with newlines to support multiple keys
  echo "${SSH_PUBLIC_KEY}" | tr '|' '\n' > "${HOME}/.ssh/authorized_keys"
  chmod 600 "${HOME}/.ssh/authorized_keys"
  echo "Added $(grep -c '^ssh-' "${HOME}/.ssh/authorized_keys") SSH key(s)"
fi

# Prevent "open browser" attempts in headless environments
export BROWSER="${BROWSER:-/usr/bin/true}"

CONFIG_DIR="${HOME}/.config/opencode"
CONFIG_FILE="${CONFIG_DIR}/opencode.json"

mkdir -p "${CONFIG_DIR}"
mkdir -p "${OPENCODE_WORKDIR}"

# Allow overriding config from workspace
if [[ -f "${OPENCODE_WORKDIR}/opencode.json" ]]; then
  echo "Found custom opencode.json in ${OPENCODE_WORKDIR}, using it."
  cp "${OPENCODE_WORKDIR}/opencode.json" "${CONFIG_FILE}"
fi

# Clone repo if GITHUB_REPO_URL is set
if [[ -n "${GITHUB_REPO_URL:-}" ]]; then
  # Remove any potential Windows carriage returns
  GITHUB_REPO_URL=$(echo "${GITHUB_REPO_URL}" | tr -d '\r')
  
  echo "Checking GitHub repository: ${GITHUB_REPO_URL}"
  ls -la "${OPENCODE_WORKDIR}" || true
  
  # Clone into a fixed directory 'project' so we can gitignore it easily
  TARGET_DIR="${OPENCODE_WORKDIR}/project"
  
  if [[ -d "${TARGET_DIR}" ]]; then
    echo "Directory ${TARGET_DIR} already exists. Skipping clone."
  else
    echo "Cloning into ${TARGET_DIR}..."
    
    # Construct URL with token if provided
    CLONE_URL="${GITHUB_REPO_URL}"
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
       GITHUB_TOKEN=$(echo "${GITHUB_TOKEN}" | tr -d '\r')
       # Insert token into URL: https://TOKEN@github.com/user/repo.git
       # Remove https://
       CLEAN_URL="${GITHUB_REPO_URL#https://}"
       CLONE_URL="https://${GITHUB_TOKEN}@${CLEAN_URL}"
    fi
    
    # Try cloning; if it fails, check if it's because it exists (race condition or weird FS state)
    git clone "${CLONE_URL}" "${TARGET_DIR}" || {
      if [[ -d "${TARGET_DIR}" ]]; then
        echo "Clone returned error but directory exists. Continuing."
      else
        echo "Git clone failed."
        exit 1
      fi
    }
  fi
fi

cors_json="[]"
cors_flags=()
if [[ -n "${OPENCODE_CORS}" ]]; then
  # turn "a,b,c" into ["a","b","c"]
  IFS=',' read -ra parts <<< "${OPENCODE_CORS}"
  cors_json="$(printf '%s\n' "${parts[@]}" | jq -R . | jq -s .)"
  for origin in "${parts[@]}"; do
    cors_flags+=(--cors "$origin")
  done
fi

# Write a minimal config once (server + plugin + safer default permissions)
# OpenCode supports configuring server settings in config. :contentReference[oaicite:0]{index=0}
if [[ ! -f "${CONFIG_FILE}" ]]; then
  cat > "${CONFIG_FILE}" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "server": {
    "hostname": "${OPENCODE_HOST}",
    "port": ${OPENCODE_PORT},
    "mdns": false,
    "cors": ${cors_json}
  },
  "plugin": ["oh-my-opencode"],
  "default_agent": "sisyphus",
  "permission": {
    "bash": "ask"
  }
}
EOF
fi

cd "${OPENCODE_WORKDIR}"
# If a repo was specified and exists (cloned above), enter it so IDE opens it as root
if [[ -n "${GITHUB_REPO_URL:-}" ]]; then
   TARGET_DIR="${OPENCODE_WORKDIR}/project"
   if [[ -d "${TARGET_DIR}" ]]; then
      echo "Entering ${TARGET_DIR}..."
      cd "${TARGET_DIR}"
   fi
fi

# Start base tmux session (opencode web + TUI)
echo "Starting base tmux session..."
tmuxp load -d /scripts/session.yaml

# Load project-specific session if exists
if [[ -f "/workspace/project/session.yaml" ]]; then
  echo "Found project session.yaml, loading..."
  tmuxp load -d /workspace/project/session.yaml
fi

# Keep container alive
exec sleep infinity
