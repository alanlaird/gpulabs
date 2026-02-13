#!/bin/bash
# Run NCCL test between GPU nodes and capture output locally

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY_FILE="$SCRIPT_DIR/ansible/inventory.yml"
SSH_KEY="$SCRIPT_DIR/id_nebius"

# Extract GPU1 IP from inventory
GPU1_IP=$(grep -A 3 "gpu1:" "$INVENTORY_FILE" | grep ansible_host | sed 's/.*: //')

if [ -z "$GPU1_IP" ]; then
    echo "❌ Error: Could not find gpu1 IP in inventory"
    exit 1
fi

# Generate timestamp for output file
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="$SCRIPT_DIR/nccl_test_${TIMESTAMP}.log"

echo "════════════════════════════════════════════════════════════"
echo "  🚀 Running NCCL Multi-Node Test"
echo "════════════════════════════════════════════════════════════"
echo "  GPU1 IP:     $GPU1_IP"
echo "  Output file: $OUTPUT_FILE"
echo "════════════════════════════════════════════════════════════"
echo ""

# Run NCCL test on gpu1 (which will communicate with gpu2)
ssh -i "$SSH_KEY" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o IdentitiesOnly=yes \
    ubuntu@"$GPU1_IP" \
    "/home/ubuntu/run_nccl_test.sh gpu2 all_reduce_perf" \
    2>&1 | tee "$OUTPUT_FILE"

echo ""
echo "════════════════════════════════════════════════════════════"
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "  ✅ Test completed successfully!"
else
    echo "  ❌ Test failed"
fi
echo "  📄 Results saved to: $OUTPUT_FILE"
echo "════════════════════════════════════════════════════════════"
