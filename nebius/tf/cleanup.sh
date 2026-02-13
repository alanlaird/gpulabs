#!/bin/bash
# Gather NCCL test reports from GPU nodes and save locally

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY_FILE="$SCRIPT_DIR/ansible/inventory.yml"
SSH_KEY="$SCRIPT_DIR/id_nebius"
REPORTS_DIR="$SCRIPT_DIR/reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Extract IPs
GPU1_IP=$(grep -A 3 "gpu1:" "$INVENTORY_FILE" | grep ansible_host | sed 's/.*: //')
if [ -z "$GPU1_IP" ]; then
    GPU1_IP=$(grep -A 3 "gpu_node_1:" "$INVENTORY_FILE" | grep ansible_host | sed 's/.*: //')
fi

GPU2_IP=$(grep -A 3 "gpu2:" "$INVENTORY_FILE" | grep ansible_host | sed 's/.*: //')
if [ -z "$GPU2_IP" ]; then
    GPU2_IP=$(grep -A 3 "gpu_node_2:" "$INVENTORY_FILE" | grep ansible_host | sed 's/.*: //')
fi

echo "════════════════════════════════════════════════════════════"
echo "  🧹 Gathering NCCL Reports from GPU Nodes"
echo "════════════════════════════════════════════════════════════"
echo "  GPU1: $GPU1_IP"
echo "  GPU2: $GPU2_IP"
echo "  Reports dir: $REPORTS_DIR"
echo "════════════════════════════════════════════════════════════"
echo ""

# Create reports directory
mkdir -p "$REPORTS_DIR"

# Function to gather reports from a node
gather_from_node() {
    local NODE_NAME=$1
    local NODE_IP=$2
    local NODE_DIR="$REPORTS_DIR/${NODE_NAME}_${TIMESTAMP}"

    echo "📥 Gathering reports from $NODE_NAME ($NODE_IP)..."
    mkdir -p "$NODE_DIR"

    # List of files to gather
    FILES_TO_GATHER=(
        "*.log"
        "*.txt"
        "nccl_test_*.out"
        "nccl-tests/*.log"
    )

    # Check for files and copy them
    for pattern in "${FILES_TO_GATHER[@]}"; do
        ssh -i "$SSH_KEY" \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -o IdentitiesOnly=yes \
            ubuntu@"$NODE_IP" \
            "find ~ -maxdepth 2 -name '$pattern' -type f 2>/dev/null" | while read -r remote_file; do

            if [ -n "$remote_file" ]; then
                filename=$(basename "$remote_file")
                echo "  📄 Copying: $filename"
                scp -i "$SSH_KEY" \
                    -o StrictHostKeyChecking=no \
                    -o UserKnownHostsFile=/dev/null \
                    -o IdentitiesOnly=yes \
                    ubuntu@"$NODE_IP":"$remote_file" \
                    "$NODE_DIR/$filename" 2>/dev/null
            fi
        done
    done

    # Count files gathered
    FILE_COUNT=$(find "$NODE_DIR" -type f | wc -l)
    echo "  ✅ Gathered $FILE_COUNT files from $NODE_NAME"
    echo ""
}

# Gather from both nodes
gather_from_node "gpu1" "$GPU1_IP"
gather_from_node "gpu2" "$GPU2_IP"

# Create summary
SUMMARY_FILE="$REPORTS_DIR/summary_${TIMESTAMP}.txt"
cat > "$SUMMARY_FILE" <<EOF
NCCL Reports Collection Summary
================================
Date: $(date)
GPU1: $GPU1_IP
GPU2: $GPU2_IP

Files collected:
EOF

find "$REPORTS_DIR" -type f -newer "$REPORTS_DIR" 2>/dev/null | while read -r file; do
    echo "  - $(basename "$file")" >> "$SUMMARY_FILE"
done

echo "════════════════════════════════════════════════════════════"
echo "  ✅ Collection complete!"
echo "════════════════════════════════════════════════════════════"
echo "  Reports saved to: $REPORTS_DIR"
echo "  Summary: $SUMMARY_FILE"
echo ""
ls -lh "$REPORTS_DIR"
echo ""
echo "To clean up remote files, run:"
echo "  ./cleanup.sh --remove-remote"
echo "════════════════════════════════════════════════════════════"

# Optional: Remove files from remote nodes
if [ "$1" == "--remove-remote" ]; then
    echo ""
    echo "🗑️  Removing NCCL reports from remote nodes..."

    for NODE_IP in "$GPU1_IP" "$GPU2_IP"; do
        ssh -i "$SSH_KEY" \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            ubuntu@"$NODE_IP" \
            "find ~ -maxdepth 2 -name '*.log' -o -name 'nccl_test_*.out' -delete 2>/dev/null"
    done

    echo "✅ Remote cleanup complete"
fi
