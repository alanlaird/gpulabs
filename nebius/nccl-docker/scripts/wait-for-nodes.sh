#!/bin/bash
# wait-for-nodes.sh — Poll SSH until both nodes are ready
# Runs checks sequentially so output is readable from Terraform local-exec.
set -e

IP1="${1:?Usage: wait-for-nodes.sh <ip1> <ip2> [timeout] [ssh_user] [ssh_key]}"
IP2="${2:?}"
TIMEOUT="${3:-600}"
SSH_USER="${4:-ubuntu}"
SSH_KEY="${5:-$(dirname "$0")/../id_nccl_docker}"

# GPU nodes take at least 60s to boot — skip early retries
INITIAL_WAIT=60

wait_for_ssh() {
    local ip=$1 label=$2
    local start elapsed

    # TCP port check — faster to fail than SSH handshake
    tcp_open() {
        timeout 5 bash -c ">/dev/tcp/${ip}/22" 2>/dev/null
    }

    # Hard-kill SSH after 12s to avoid hangs when port is open but sshd not ready.
    # IdentitiesOnly=yes is critical: without it the SSH agent offers all loaded keys
    # first, exhausting the server's MaxAuthTries before the key file is ever tried.
    ssh_ok() {
        timeout 12 ssh \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -o ConnectTimeout=8 \
            -o BatchMode=yes \
            -o IdentitiesOnly=yes \
            -o ServerAliveInterval=3 \
            -o ServerAliveCountMax=2 \
            -i "$SSH_KEY" \
            "${SSH_USER}@${ip}" "exit 0" 2>/dev/null
    }

    echo "  [$label] Waiting for $ip (boot delay ${INITIAL_WAIT}s)..."
    sleep "$INITIAL_WAIT"

    start=$(date +%s)
    while true; do
        elapsed=$(( $(date +%s) - start + INITIAL_WAIT ))
        if [ $elapsed -ge $TIMEOUT ]; then
            echo "  [$label] ERROR: Timeout after ${TIMEOUT}s — node never became SSH-ready"
            return 1
        fi

        printf "  [%s] %3ds  " "$label" "$elapsed"

        if ! tcp_open; then
            echo "port 22 not yet open, retrying..."
            sleep 10
            continue
        fi

        echo -n "port open, testing SSH... "
        if ssh_ok; then
            echo "OK"
            echo "  [$label] Ready after ${elapsed}s"
            return 0
        fi

        echo "sshd not ready yet, retrying..."
        sleep 10
    done
}

wait_for_ssh "$IP1" "Node 1"
wait_for_ssh "$IP2" "Node 2"
echo "  Both nodes SSH-ready."
