# syntax=docker/dockerfile:1.6
FROM node:20-bookworm-slim

ARG USER=dev
ARG UID=1000
ARG GID=1000
ARG TTYD_VERSION=1.7.7
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git openssh-client bash zsh tini \
      ripgrep jq unzip \
      python3 python3-venv make g++ \
    && rm -rf /var/lib/apt/lists/*

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# Install Bun (globally for the binary)
# We use a temporary env var so it doesn't persist as /usr/local for the user
RUN export BUN_INSTALL=/usr/local && \
    curl -fsSL https://bun.sh/install | bash

# Install OpenCode (binary via official installer)
# The installer puts it in $HOME/.opencode/bin. Since we run as root, that's /root/.opencode/bin.
# We move it to /usr/local/bin so it's globally available.
RUN curl -fsSL https://opencode.ai/install | bash && \
    mv /root/.opencode/bin/opencode /usr/local/bin/opencode && \
    chmod +x /usr/local/bin/opencode

# Install Oh-My-OpenCode (Agent Harness) + common language servers for TanStack (TypeScript/React)
RUN corepack enable && \
    npm install -g \
      oh-my-opencode \
      typescript \
      typescript-language-server \
      vscode-langservers-extracted \
      @tailwindcss/language-server \
      yaml-language-server \
      bash-language-server \
      dockerfile-language-server-nodejs \
      graphql-language-service-cli \
      @prisma/language-server \
    && npm cache clean --force

# Install ttyd (web terminal) as a static binary
RUN set -eux; \
  case "$TARGETARCH" in \
    amd64) T="x86_64" ;; \
    arm64) T="aarch64" ;; \
    *) echo "Unsupported arch: $TARGETARCH" && exit 1 ;; \
  esac; \
  curl -fsSL -o /usr/local/bin/ttyd "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.${T}"; \
  chmod +x /usr/local/bin/ttyd; \
  /usr/local/bin/ttyd -v || true

# Create non-root user (safely handling potential conflicts)
RUN (userdel -r node || true) && \
    (groupdel node || true) && \
    groupadd --gid ${GID} ${USER} && \
    useradd --uid ${UID} --gid ${GID} -m -s /bin/bash ${USER} && \
    mkdir -p /home/${USER}/.config/opencode /home/${USER}/.local/share/opencode && \
    chown -R ${UID}:${GID} /home/${USER}

# Copy configuration files (using wildcards to make them optional)
COPY --chown=${UID}:${GID} opencode_config/auth.json* /home/${USER}/.local/share/opencode/
COPY --chown=${UID}:${GID} opencode_config/antigravity-accounts.json* /home/${USER}/.config/opencode/
COPY --chown=${UID}:${GID} opencode_config/oh-my-opencode.json* /home/${USER}/.config/opencode/
COPY --chown=${UID}:${GID} opencode_config/opencode.json* /home/${USER}/.config/opencode/

WORKDIR /workspace

# Entrypoint
COPY scripts/ /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh

# Configure Bun and uv for the non-root user
ENV BUN_INSTALL=/home/${USER}/.bun
ENV PATH=${BUN_INSTALL}/bin:/home/${USER}/.local/bin:${PATH}

USER ${USER}

# Pre-install oh-my-opencode with bun to ensure it's available and bun works
RUN bun install -g oh-my-opencode

# Install spec-kit (specify-cli)
RUN uv tool install specify-cli --from git+https://github.com/github/spec-kit.git

EXPOSE 4096

ENTRYPOINT ["/usr/bin/tini","--","/usr/local/bin/entrypoint.sh"]
CMD ["opencode-web"]
