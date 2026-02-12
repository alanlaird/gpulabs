#!/bin/bash
set -e

# Wait for GPU nodes to be ready for SSH connections
# Usage: ./wait-for-nodes.sh <ip1> <ip2> [timeout_seconds]

IP1="${1:-}"
IP2="${2:-}"
TIMEOUT="${3:-300}"  # 5 minutes default
SSH_USER="${4:-ubuntu}"
SSH_KEY="${5:-../id_nebius}"

if [ -z "$IP1" ] || [ -z "$IP2" ]; then
    echo "Usage: $0 <ip1> <ip2> [timeout] [ssh_user] [ssh_key]"
    exit 1
fi

echo "════════════════════════════════════════════════════════════"
echo "  Waiting for GPU nodes to be ready..."
echo "════════════════════════════════════════════════════════════"
echo "  Node 1: $IP1"
echo "  Node 2: $IP2"
echo "  Timeout: ${TIMEOUT}s"
echo "  SSH User: $SSH_USER"
echo "  SSH Key: $SSH_KEY"
echo "════════════════════════════════════════════════════════════"
echo ""

wait_for_ssh() {
    local ip=$1
    local start_time=$(date +%s)
    local node_name=$2

    echo "⏳ Waiting for $node_name ($ip) to accept SSH connections..."

    while true; do
        current_time=$(date +%s)
        elapsed=$((current_time - start_time))

        if [ $elapsed -ge $TIMEOUT ]; then
            echo "❌ Timeout waiting for $node_name after ${TIMEOUT}s"
            return 1
        fi

        if ssh -o StrictHostKeyChecking=no \
               -o UserKnownHostsFile=/dev/null \
               -o ConnectTimeout=5 \
               -o BatchMode=yes \
               -i "$SSH_KEY" \
               "${SSH_USER}@${ip}" \
               "echo 'SSH ready'" &>/dev/null; then
            echo "✅ $node_name is ready! (${elapsed}s)"
            return 0
        fi

        printf "."
        sleep 5
    done
}

# Wait for both nodes
wait_for_ssh "$IP1" "Node 1" &
PID1=$!

wait_for_ssh "$IP2" "Node 2" &
PID2=$!

# Wait for both background jobs
FAILED=0
wait $PID1 || FAILED=1
wait $PID2 || FAILED=1

echo ""
if [ $FAILED -eq 0 ]; then
    echo "════════════════════════════════════════════════════════════"
    echo "  ✅ All nodes are ready!"
    echo "════════════════════════════════════════════════════════════"
    exit 0
else
    echo "════════════════════════════════════════════════════════════"
    echo "  ❌ Some nodes failed to become ready"
    echo "════════════════════════════════════════════════════════════"
    exit 1
fi
