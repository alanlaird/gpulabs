#!/bin/bash
# Show GPU node uptime and connection info

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

echo -e "${BOLD}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║              GPU NODES STATUS & CONNECTION INFO                ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Cost configuration (L40S GPU)
COST_PER_INSTANCE_HOUR=1.55
COST_TOTAL_HOUR=3.10
NUM_INSTANCES=2

# Get IPs from inventory
NODE1_IP=$(grep -A1 "gpu_node_1:" ansible/inventory.yml | grep "ansible_host:" | awk '{print $2}')
NODE2_IP=$(grep -A1 "gpu_node_2:" ansible/inventory.yml | grep "ansible_host:" | awk '{print $2}')

SSH_KEY="./id_nebius"
SSH_USER="ubuntu"
SSH_OPTS="-o StrictHostKeyChecking=no -o IdentitiesOnly=yes -o ConnectTimeout=5 -o BatchMode=yes"

check_node() {
    local node_name=$1
    local node_ip=$2

    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${BLUE}  $node_name${NC}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # SSH Command
    echo -e "${YELLOW}📡 SSH Command:${NC}"
    echo -e "   ${GREEN}ssh -i $SSH_KEY $SSH_USER@$node_ip${NC}"
    echo ""

    # Try to connect and get info
    echo -e "${YELLOW}📊 Status:${NC}"

    if ssh $SSH_OPTS -i $SSH_KEY $SSH_USER@$node_ip "echo 'Connected'" &>/dev/null; then
        echo -e "   ${GREEN}✓ Online${NC}"
        echo ""

        # Get detailed info
        info=$(ssh $SSH_OPTS -i $SSH_KEY $SSH_USER@$node_ip '
            echo "HOSTNAME=\"$(hostname)\""
            echo "UPTIME=\"$(uptime -p | sed "s/up //")\""
            echo "UPTIME_SECONDS=\"$(cat /proc/uptime | cut -d. -f1)\""
            echo "BOOT=\"$(uptime -s)\""
            echo "LOAD=\"$(uptime | grep -oP "load average: \K.*")\""
            echo "GPU=\"$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo "N/A")\""
            echo "GPU_TEMP=\"$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null || echo "N/A")°C\""
            echo "GPU_MEM=\"$(nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null || echo "N/A")\""
            echo "DISK=\"$(df -h / | tail -1 | awk "{print \$3 \"/\" \$2 \" (\" \$5 \")\"}")\""
            echo "IP=\"$(hostname -I | awk "{print \$1}")\""
        ' 2>/dev/null)

        # Parse and display info
        eval "$info"

        # Calculate cost for this node
        UPTIME_HOURS=$(echo "scale=2; $UPTIME_SECONDS / 3600" | bc)
        NODE_COST=$(echo "scale=2; $UPTIME_HOURS * $COST_PER_INSTANCE_HOUR" | bc)

        echo -e "${YELLOW}🖥️  Hostname:${NC}      $HOSTNAME"
        echo -e "${YELLOW}🕒 Uptime:${NC}         $UPTIME"
        echo -e "${YELLOW}📅 Boot Time:${NC}      $BOOT"
        echo -e "${YELLOW}📊 Load Average:${NC}   $LOAD"
        echo -e "${YELLOW}🎮 GPU:${NC}            $GPU"
        echo -e "${YELLOW}🌡️  GPU Temp:${NC}       $GPU_TEMP"
        echo -e "${YELLOW}💾 GPU Memory:${NC}     $GPU_MEM MiB"
        echo -e "${YELLOW}💽 Disk Usage:${NC}     $DISK"
        echo -e "${YELLOW}🌐 Private IP:${NC}     $IP"
        echo -e "${YELLOW}💰 Cost So Far:${NC}    \$$NODE_COST (${UPTIME_HOURS}h @ \$${COST_PER_INSTANCE_HOUR}/h)"

        # Store uptime for total calculation
        if [ "$node_name" = "Node 1" ]; then
            NODE1_UPTIME_HOURS=$UPTIME_HOURS
            NODE1_COST=$NODE_COST
        else
            NODE2_UPTIME_HOURS=$UPTIME_HOURS
            NODE2_COST=$NODE_COST
        fi

    else
        echo -e "   ${RED}✗ Offline or unreachable${NC}"
    fi

    echo ""
}

# Check both nodes
check_node "Node 1" "$NODE1_IP"
check_node "Node 2" "$NODE2_IP"

echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${BLUE}  Cost Summary${NC}"
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Calculate total costs if both nodes are online
if [ -n "$NODE1_COST" ] && [ -n "$NODE2_COST" ]; then
    TOTAL_COST=$(echo "scale=2; $NODE1_COST + $NODE2_COST" | bc)
    AVG_UPTIME=$(echo "scale=2; ($NODE1_UPTIME_HOURS + $NODE2_UPTIME_HOURS) / 2" | bc)

    # Projected costs
    PROJECTED_DAILY=$(echo "scale=2; $COST_TOTAL_HOUR * 24" | bc)
    PROJECTED_MONTHLY=$(echo "scale=2; $PROJECTED_DAILY * 30" | bc)

    echo -e "${YELLOW}💵 Total Cost So Far:${NC}      \$$TOTAL_COST"
    echo -e "${YELLOW}⏱️  Average Uptime:${NC}         ${AVG_UPTIME}h"
    echo -e "${YELLOW}📊 Hourly Rate:${NC}            \$$COST_TOTAL_HOUR/h (both nodes)"
    echo -e "${YELLOW}📅 Projected Daily:${NC}        \$$PROJECTED_DAILY/day"
    echo -e "${YELLOW}📆 Projected Monthly:${NC}      \$$PROJECTED_MONTHLY/month"
    echo -e ""
    echo -e "${RED}⚠️  Remember to destroy when done to stop charges!${NC}"
elif [ -n "$NODE1_COST" ] || [ -n "$NODE2_COST" ]; then
    ACTIVE_COST=${NODE1_COST:-$NODE2_COST}
    echo -e "${YELLOW}💵 Cost (Active Node):${NC}     \$$ACTIVE_COST"
    echo -e "${YELLOW}📊 Rate per Node:${NC}          \$${COST_PER_INSTANCE_HOUR}/h"
else
    echo -e "${RED}No nodes online - no costs incurred${NC}"
fi
echo ""

echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${BLUE}  Quick Commands${NC}"
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Connect to nodes:${NC}"
echo -e "  ${GREEN}ssh -i $SSH_KEY $SSH_USER@$NODE1_IP${NC}  # Node 1"
echo -e "  ${GREEN}ssh -i $SSH_KEY $SSH_USER@$NODE2_IP${NC}  # Node 2"
echo ""
echo -e "${YELLOW}Run Ansible playbook:${NC}"
echo -e "  ${GREEN}./run-ansible.sh${NC}"
echo ""
echo -e "${YELLOW}Check GPU on all nodes:${NC}"
echo -e "  ${GREEN}cd ansible && ansible gpu_nodes -i inventory.yml -a 'nvidia-smi'${NC}"
echo ""
echo -e "${YELLOW}Destroy infrastructure (STOP CHARGES):${NC}"
echo -e "  ${GREEN}terraform destroy${NC}"
echo ""
