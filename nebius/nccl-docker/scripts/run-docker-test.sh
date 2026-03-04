#!/bin/bash
# run-docker-test.sh — Run NCCL tests on both GPU nodes via Docker + MPI
# Called by 'make test'
#
# Runs two phases:
#   Phase 1 (per-node):  Docker benchmark on each node independently
#   Phase 2 (internode): MPI-coordinated benchmark across both nodes
#
# Usage: run-docker-test.sh [min_size] [max_size]
set -e

MIN_SIZE="${1:-8}"
MAX_SIZE="${2:-128M}"
NRANKS="${3:-2}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
INVENTORY="$BASE_DIR/ansible/inventory.yml"
SSH_KEY="$BASE_DIR/id_nccl_docker"
RESULTS_DIR="$BASE_DIR/results"

NCCL_IMAGE="${NCCL_IMAGE:-ghcr.io/coreweave/nccl-tests:13.0.2-devel-ubuntu24.04-nccl2.29.2-1-d73ec07}"

# ── Extract IPs from inventory ────────────────────────────────────────────────
GPU1_IP=$(grep -A3 "gpu1:" "$INVENTORY" | grep ansible_host | awk '{print $2}')
GPU2_IP=$(grep -A3 "gpu2:" "$INVENTORY" | grep ansible_host | awk '{print $2}')

if [ -z "$GPU1_IP" ] || [ -z "$GPU2_IP" ]; then
    echo "ERROR: Could not read node IPs from $INVENTORY"
    echo "  Run 'make create' first."
    exit 1
fi

mkdir -p "$RESULTS_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

SSH_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes"

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  NCCL Docker Test Suite"
echo "════════════════════════════════════════════════════════════"
echo "  Node 1:    $GPU1_IP"
echo "  Node 2:    $GPU2_IP"
echo "  Image:     $NCCL_IMAGE"
echo "  Msg range: $MIN_SIZE .. $MAX_SIZE"
echo "  NRANKS:    $NRANKS"
echo "  Results:   $RESULTS_DIR/"
echo "════════════════════════════════════════════════════════════"
echo ""

# ── Phase 1a: Per-node Docker test on Node 1 ─────────────────────────────────
echo "[ Phase 1a ] Per-node Docker benchmark — Node 1 ($GPU1_IP)"
echo "────────────────────────────────────────────────────────────"
OUTFILE_1="$RESULTS_DIR/node1_docker_${TIMESTAMP}.log"

ssh $SSH_OPTS ubuntu@"$GPU1_IP" \
    "docker run --gpus all --rm \
        -e NCCL_DEBUG=WARN \
        $NCCL_IMAGE \
        /opt/nccl-tests/build/all_reduce_perf \
        -b $MIN_SIZE -e $MAX_SIZE -f 2 -g 1" \
    2>&1 | tee "$OUTFILE_1"

echo ""
echo "  Saved: $OUTFILE_1"
echo ""

# ── Phase 1b: Per-node Docker test on Node 2 ─────────────────────────────────
echo "[ Phase 1b ] Per-node Docker benchmark — Node 2 ($GPU2_IP)"
echo "────────────────────────────────────────────────────────────"
OUTFILE_2="$RESULTS_DIR/node2_docker_${TIMESTAMP}.log"

ssh $SSH_OPTS ubuntu@"$GPU2_IP" \
    "docker run --gpus all --rm \
        -e NCCL_DEBUG=WARN \
        $NCCL_IMAGE \
        /opt/nccl-tests/build/all_reduce_perf \
        -b $MIN_SIZE -e $MAX_SIZE -f 2 -g 1" \
    2>&1 | tee "$OUTFILE_2"

echo ""
echo "  Saved: $OUTFILE_2"
echo ""

# ── Phase 2: Inter-node MPI benchmark ────────────────────────────────────────
echo "[ Phase 2  ] Inter-node NCCL benchmark (Node 1 <-> Node 2)"
echo "────────────────────────────────────────────────────────────"
OUTFILE_INTER="$RESULTS_DIR/internode_${TIMESTAMP}.log"

ssh $SSH_OPTS ubuntu@"$GPU1_IP" \
    "/home/ubuntu/run_docker_nccl_test.sh $GPU2_IP $MIN_SIZE $MAX_SIZE $NRANKS" \
    2>&1 | tee "$OUTFILE_INTER"

STATUS=${PIPESTATUS[0]}
echo ""
echo "  Saved: $OUTFILE_INTER"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════"
if [ $STATUS -eq 0 ]; then
    echo "  All tests completed successfully."
    echo ""
    echo "  Per-node peaks:"
    for LOG in "$OUTFILE_1" "$OUTFILE_2"; do
        NODE=$(basename "$LOG" | sed 's/_docker_.*//')
        PEAK=$(grep -E "^[[:space:]]*[0-9]" "$LOG" 2>/dev/null | tail -1 || true)
        [ -n "$PEAK" ] && echo "    $NODE: $PEAK"
    done
    echo ""
    echo "  Inter-node peak:"
    PEAK_INTER=$(grep -E "^[[:space:]]*[0-9]" "$OUTFILE_INTER" 2>/dev/null | tail -1 || true)
    [ -n "$PEAK_INTER" ] && echo "    $PEAK_INTER"
else
    echo "  Inter-node test FAILED (exit $STATUS)."
    echo "  Check $OUTFILE_INTER for details."
fi
echo ""
echo "  Results directory: $RESULTS_DIR/"
echo "════════════════════════════════════════════════════════════"
exit $STATUS
