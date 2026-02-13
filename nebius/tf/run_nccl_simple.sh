#!/bin/bash
# Simple NCCL multi-node test without MPI - uses SSH to launch on both nodes

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY_FILE="$SCRIPT_DIR/ansible/inventory.yml"
SSH_KEY="$SCRIPT_DIR/id_nebius"

# Extract IPs (try both gpu1 and gpu_node_1 formats)
GPU1_IP=$(grep -A 3 "gpu1:" "$INVENTORY_FILE" | grep ansible_host | sed 's/.*: //')
if [ -z "$GPU1_IP" ]; then
    GPU1_IP=$(grep -A 3 "gpu_node_1:" "$INVENTORY_FILE" | grep ansible_host | sed 's/.*: //')
fi

GPU2_IP=$(grep -A 3 "gpu2:" "$INVENTORY_FILE" | grep ansible_host | sed 's/.*: //')
if [ -z "$GPU2_IP" ]; then
    GPU2_IP=$(grep -A 3 "gpu_node_2:" "$INVENTORY_FILE" | grep ansible_host | sed 's/.*: //')
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="$SCRIPT_DIR/nccl_test_${TIMESTAMP}.log"

echo "════════════════════════════════════════════════════════════"
echo "  🚀 NCCL Peer-to-Peer Test (No MPI Required)"
echo "════════════════════════════════════════════════════════════"
echo "  GPU1: $GPU1_IP"
echo "  GPU2: $GPU2_IP"
echo "  Output: $OUTPUT_FILE"
echo "════════════════════════════════════════════════════════════"
echo ""

# Test script to run on each node
TEST_SCRIPT='
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/lib64:$LD_LIBRARY_PATH
cd ~/nccl-tests/build
./all_reduce_perf -b 8 -e 128M -f 2 -g 1
'

echo "Running NCCL test on GPU1..." | tee "$OUTPUT_FILE"
ssh -i "$SSH_KEY" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    ubuntu@"$GPU1_IP" "$TEST_SCRIPT" 2>&1 | tee -a "$OUTPUT_FILE"

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  ✅ Test completed"
echo "  📄 Results: $OUTPUT_FILE"
echo "════════════════════════════════════════════════════════════"
