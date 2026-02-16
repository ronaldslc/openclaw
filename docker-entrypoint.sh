#!/bin/sh
# Fix permissions of the volume
# This script runs as root to perform initialization, then drops to node user

echo "Fixing home and volume permissions..."
chown -R node:node /home/node

# 3. Clean up stale chrome lock files to prevent startup timeouts
echo "Cleaning up stale chrome lock files..."
find /home/node -name "SingletonLock" -exec rm -v {} +

# 1. Create a symlink for Path Symmetry if OPENCLAW_HOME is a host path.
# This allows the container to resolve host-absolute paths locally.
if [ -n "$OPENCLAW_HOME" ] && [ "$OPENCLAW_HOME" != "/home/node" ]; then
    echo "Path Symmetry: Link $OPENCLAW_HOME -> /home/node"
    mkdir -p "$(dirname "$OPENCLAW_HOME")"
    rm -f "$OPENCLAW_HOME" 
    ln -sf /home/node "$OPENCLAW_HOME"
fi

# 2. Get the group ID of the mounted docker socket
if [ -S /var/run/docker.sock ]; then
    DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
    echo "Found docker socket with GID $DOCKER_GID"

    # 2. Check if a group with that ID already exists
    DOCKER_GROUP=$(getent group "$DOCKER_GID" | cut -d: -f1)
    if [ -z "$DOCKER_GROUP" ]; then
        # If not, create a group named 'docker-host' with that ID
        groupadd -g "$DOCKER_GID" docker-host
        DOCKER_GROUP="docker-host"
    fi

    # 3. Add the 'node' user to that group
    usermod -aG "$DOCKER_GROUP" node
    echo "Added node user to group $DOCKER_GROUP"
fi

# Start Xvfb for headless browser support if no DISPLAY is provided
if [ -z "$DISPLAY" ]; then
    echo "No DISPLAY set, starting Xvfb on :99"
    Xvfb :99 -screen 0 1280x1024x24 -ac &
    export DISPLAY=:99
else
    echo "Using existing DISPLAY=$DISPLAY"
fi

# Execute the main command as the 'node' user
# using 'setpriv' to drop privileges clearly and handle signals correctly
exec setpriv --reuid=node --regid=node --init-groups "$@"
