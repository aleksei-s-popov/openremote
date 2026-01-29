#!/usr/bin/env bash
set -euo pipefail

SUPERPOWERS_REPO="https://github.com/obra/superpowers.git"
SUPERPOWERS_DIR="${HOME}/.config/opencode/superpowers"
PLUGINS_DIR="${HOME}/.config/opencode/plugins"
SKILLS_DIR="${HOME}/.config/opencode/skills"

echo "Installing superpowers for OpenCode..."

if [ -d "${SUPERPOWERS_DIR}" ]; then
  echo "Updating existing superpowers installation..."
  cd "${SUPERPOWERS_DIR}" && git pull
else
  echo "Cloning superpowers repository..."
  git clone "${SUPERPOWERS_REPO}" "${SUPERPOWERS_DIR}"
fi

echo "Creating required directories..."
mkdir -p "${PLUGINS_DIR}" "${SKILLS_DIR}"

echo "Removing any existing links..."
rm -f "${PLUGINS_DIR}/superpowers.js"
rm -rf "${SKILLS_DIR}/superpowers"

echo "Creating symlinks..."
ln -s "${SUPERPOWERS_DIR}/.opencode/plugins/superpowers.js" "${PLUGINS_DIR}/superpowers.js"
ln -s "${SUPERPOWERS_DIR}/skills" "${SKILLS_DIR}/superpowers"

echo "Verifying installation..."
if [ -L "${PLUGINS_DIR}/superpowers.js" ] && [ -L "${SKILLS_DIR}/superpowers" ]; then
  echo "✓ Superpowers installed successfully!"
  echo "  Plugin: ${PLUGINS_DIR}/superpowers.js"
  echo "  Skills: ${SKILLS_DIR}/superpowers"
else
  echo "✗ Installation verification failed!"
  exit 1
fi
