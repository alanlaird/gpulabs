#!/bin/bash
# Validate SSH connections to GPU nodes

echo "🔍 Validating SSH connections to GPU instances..."
echo ""

# Get IPs from terraform
NODE1_IP=$(terraform output -raw gpu_node_1_ssh | cut -d'@' -f2 | cut -d'/' -f1)
NODE2_IP=$(terraform output -raw gpu_node_2_ssh | cut -d'@' -f2 | cut -d'/' -f1)

echo "📡 Node 1: $NODE1_IP"
echo "📡 Node 2: $NODE2_IP"
echo ""

# Test Node 1
echo "═══════════════════════════════════════════════════════════"
echo "Testing Node 1 ($NODE1_IP)..."
echo "═══════════════════════════════════════════════════════════"
ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 ubuntu@$NODE1_IP '
echo "✅ SSH Connection: SUCCESS"
echo ""
echo "📋 Hostname: $(hostname)"
echo "🖥️  OS: $(lsb_release -d | cut -f2)"
echo "🐧 Kernel: $(uname -r)"
echo ""
echo "🎮 GPU Information:"
nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
echo ""
echo "⚡ CUDA Version:"
nvcc --version | grep "release" | awk "{print \$5, \$6}"
echo ""
echo "💾 Disk Space:"
df -h / | tail -1 | awk "{print \"Used: \" \$3 \" / \" \$2 \" (\" \$5 \")\"}"
' 2>&1
EXIT_CODE1=$?
echo ""

# Test Node 2
echo "═══════════════════════════════════════════════════════════"
echo "Testing Node 2 ($NODE2_IP)..."
echo "═══════════════════════════════════════════════════════════"
ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 ubuntu@$NODE2_IP '
echo "✅ SSH Connection: SUCCESS"
echo ""
echo "📋 Hostname: $(hostname)"
echo "🖥️  OS: $(lsb_release -d | cut -f2)"
echo "🐧 Kernel: $(uname -r)"
echo ""
echo "🎮 GPU Information:"
nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
echo ""
echo "⚡ CUDA Version:"
nvcc --version | grep "release" | awk "{print \$5, \$6}"
echo ""
echo "💾 Disk Space:"
df -h / | tail -1 | awk "{print \"Used: \" \$3 \" / \" \$2 \" (\" \$5 \")\"}"
' 2>&1
EXIT_CODE2=$?
echo ""

# Summary
echo "═══════════════════════════════════════════════════════════"
echo "📊 Summary"
echo "═══════════════════════════════════════════════════════════"
if [ $EXIT_CODE1 -eq 0 ]; then
    echo "✅ Node 1: Connected and validated"
else
    echo "❌ Node 1: Connection failed (exit code: $EXIT_CODE1)"
fi

if [ $EXIT_CODE2 -eq 0 ]; then
    echo "✅ Node 2: Connected and validated"
else
    echo "❌ Node 2: Connection failed (exit code: $EXIT_CODE2)"
fi
echo ""

if [ $EXIT_CODE1 -eq 0 ] && [ $EXIT_CODE2 -eq 0 ]; then
    echo "🎉 All nodes are accessible and GPU-ready!"
    exit 0
else
    echo "⚠️  Some nodes failed validation"
    exit 1
fi
