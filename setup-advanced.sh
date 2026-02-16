#!/usr/bin/env bash
set -euo pipefail

# setup-advanced.sh - One-step setup for OpenClaw with Sandbox/DooD support
# This script prepares an isolated home directory, sets up path symmetry, 
# and configures the layered Docker gateway.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

# 1. Configuration Constants
DEFAULT_HOME_DIR="$HOME/openclaw_home"
OPENCLAW_HOME_BASE="${1:-$DEFAULT_HOME_DIR}"
OPENCLAW_HOME_ABS="$(realpath "$OPENCLAW_HOME_BASE")"

echo "==> Preparing Advanced OpenClaw Environment at: $OPENCLAW_HOME_ABS"
mkdir -p "$OPENCLAW_HOME_ABS"

# 2. Consolidation Logic
if [ -d "$HOME/.openclaw" ] && [ ! -d "$OPENCLAW_HOME_ABS/.openclaw" ]; then
    echo "    Detected config at ~/.openclaw, moving to consolidated home..."
    mv "$HOME/.openclaw" "$OPENCLAW_HOME_ABS/"
fi
mkdir -p "$OPENCLAW_HOME_ABS/.openclaw/workspace"

# 3. Environment Variable Preparation
echo "==> Writing .env and .env.extra"

cat > .env <<EOF
OPENCLAW_CONFIG_DIR=$OPENCLAW_HOME_ABS/.openclaw
OPENCLAW_WORKSPACE_DIR=$OPENCLAW_HOME_ABS/.openclaw/workspace
OPENCLAW_GATEWAY_PORT=18789
OPENCLAW_BRIDGE_PORT=18790
OPENCLAW_GATEWAY_BIND=lan
OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 24 2>/dev/null || echo "clawtok_$(date +%s)")
OPENCLAW_IMAGE=openclaw:local
OPENCLAW_EXTRA_MOUNTS=
OPENCLAW_HOME_VOLUME=$OPENCLAW_HOME_ABS
EOF

cat > .env.extra <<EOF
OPENCLAW_HOME=$OPENCLAW_HOME_ABS
EOF

# 4. Generate the Enhanced Compose File
echo "==> Generating docker-compose.extra.yml"
cat > docker-compose.extra.yml <<EOF
services:
  openclaw-gateway:
    image: \${OPENCLAW_IMAGE:-openclaw:local}-gateway
    build:
      context: .
      dockerfile: Dockerfile.gateway
      args:
        BASE_IMAGE: \${OPENCLAW_IMAGE:-openclaw:local}
    depends_on:
      - openclaw-cli
    env_file:
      - .env.extra
    environment:
      - DISPLAY=\${DISPLAY:-}
    volumes:
      - $OPENCLAW_HOME_ABS:/home/node
      - /var/run/docker.sock:/var/run/docker.sock
      - /tmp/.X11-unix:/tmp/.X11-unix
  openclaw-cli:
    volumes:
      - $OPENCLAW_HOME_ABS:/home/node
EOF

# 5. Build and Initialize
echo "==> Building base image..."
docker build -t openclaw:local -f Dockerfile .

echo "==> Building layered gateway image..."
make build

# 6. Automatic Config Patching
CONFIG_FILE="$OPENCLAW_HOME_ABS/.openclaw/openclaw.json"
if [ -f "$CONFIG_FILE" ]; then
    echo "==> Patching openclaw.json for advanced sandbox/browser integration..."
    
    # Use jq to update the configuration safely
    tmp_cfg=$(mktemp)
    jq '
      .agents.defaults.workspace = "~/.openclaw/workspace" |
      .agents.defaults.sandbox.workspaceAccess = "rw" |
      .agents.defaults.sandbox.browser.enabled = false |
      .agents.defaults.sandbox.browser.allowHostControl = true |
      .browser.enabled = true |
      .browser.noSandbox = true |
      .browser.defaultProfile = "openclaw" |
      .tools.sandbox.tools.allow = [
        "browser", "exec", "process", "read", "write", "edit", 
        "apply_patch", "image", "sessions_list", "sessions_history", 
        "sessions_send", "sessions_spawn", "subagents", "session_status",
        "web_search", "web_fetch"
      ]
    ' "$CONFIG_FILE" > "$tmp_cfg" && mv "$tmp_cfg" "$CONFIG_FILE"
    
    # Ensure tilde expansion for workspace
    sed -i 's|"/home/node/.openclaw/workspace"|"~/.openclaw/workspace"|g' "$CONFIG_FILE"
fi

echo "==> Running Onboarding..."
docker compose -f docker-compose.yml -f docker-compose.extra.yml run --rm openclaw-cli onboard --no-install-daemon

echo ""
echo "DONE! Your advanced environment is ready."
echo "Config/Workspace: $OPENCLAW_HOME_ABS/.openclaw"
echo "Isolated Home:    $OPENCLAW_HOME_ABS"
echo ""
echo "To start OpenClaw:  make start"
echo "To access CLI:      make cli <command>"
echo ""
echo "Note: If you have existing API keys, add them to .env.extra"
