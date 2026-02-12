#!/bin/bash
# Pre-flight check script for Nebius GPU deployment
# Verifies all prerequisites are met before running terraform

set -e

BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BOLD}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║        Nebius GPU Deployment - Pre-flight Check              ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Track overall status
ALL_CHECKS_PASSED=true

# Function to print check status
check_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
        ALL_CHECKS_PASSED=false
    fi
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Function to print info
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

echo -e "${BOLD}1. Checking Required Tools${NC}"
echo "─────────────────────────────────────────────────────────────────"

# Check Terraform
if command -v terraform &> /dev/null; then
    TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version' 2>/dev/null || terraform version | head -1 | awk '{print $2}')
    check_status 0 "Terraform installed: $TERRAFORM_VERSION"
else
    check_status 1 "Terraform not found. Install from: https://developer.hashicorp.com/terraform/install"
fi

# Check Nebius CLI
if command -v nebius &> /dev/null; then
    check_status 0 "Nebius CLI installed"
    
    # Test authentication
    if nebius profile list &> /dev/null; then
        check_status 0 "Nebius CLI authenticated"
    else
        check_status 1 "Nebius CLI not authenticated. Run: nebius profile create"
    fi
else
    check_status 1 "Nebius CLI not found. Install from: https://docs.nebius.com/cli/"
fi

# Check jq
if command -v jq &> /dev/null; then
    JQ_VERSION=$(jq --version)
    check_status 0 "jq installed: $JQ_VERSION"
else
    check_status 1 "jq not found. Install: apt install jq (Ubuntu) or brew install jq (Mac)"
fi

echo ""
echo -e "${BOLD}2. Checking Configuration Files${NC}"
echo "─────────────────────────────────────────────────────────────────"

# Check for terraform.tfvars
if [ -f "terraform.tfvars" ]; then
    check_status 0 "terraform.tfvars exists"
    
    # Check for required variables
    if grep -q "^parent_id" terraform.tfvars && ! grep -q "^parent_id.*=.*\"\"" terraform.tfvars; then
        check_status 0 "parent_id is configured"
    else
        check_status 1 "parent_id not configured in terraform.tfvars"
    fi
    
    if grep -q "^ssh_public_key" terraform.tfvars && ! grep -q "^ssh_public_key.*=.*\"\"" terraform.tfvars; then
        check_status 0 "ssh_public_key is configured"
    else
        check_status 1 "ssh_public_key not configured in terraform.tfvars"
    fi
else
    check_status 1 "terraform.tfvars not found. Copy from terraform.tfvars.example"
fi

# Check .terraformrc
if [ -f "$HOME/.terraformrc" ]; then
    check_status 0 ".terraformrc exists in home directory"
else
    print_warning ".terraformrc not found in home directory"
    print_info "Run: cp .terraformrc ~/.terraformrc"
fi

echo ""
echo -e "${BOLD}3. Checking Automation Scripts${NC}"
echo "─────────────────────────────────────────────────────────────────"

# Check scripts exist and are executable
if [ -f "scripts/find-latest-image.sh" ]; then
    if [ -x "scripts/find-latest-image.sh" ]; then
        check_status 0 "find-latest-image.sh exists and is executable"
    else
        check_status 1 "find-latest-image.sh not executable. Run: chmod +x scripts/find-latest-image.sh"
    fi
else
    check_status 1 "find-latest-image.sh not found"
fi

if [ -f "scripts/find-subnet.sh" ]; then
    if [ -x "scripts/find-subnet.sh" ]; then
        check_status 0 "find-subnet.sh exists and is executable"
    else
        check_status 1 "find-subnet.sh not executable. Run: chmod +x scripts/find-subnet.sh"
    fi
else
    check_status 1 "find-subnet.sh not found"
fi

echo ""
echo -e "${BOLD}4. Testing Automation Scripts${NC}"
echo "─────────────────────────────────────────────────────────────────"

# Test image detection (if CLI is available)
if command -v nebius &> /dev/null && command -v jq &> /dev/null && [ -x "scripts/find-latest-image.sh" ]; then
    print_info "Testing image detection..."
    if IMAGE_RESULT=$(echo '{"region":"eu-north1"}' | scripts/find-latest-image.sh 2>/dev/null); then
        IMAGE_ID=$(echo "$IMAGE_RESULT" | jq -r '.image_id')
        CUDA_VERSION=$(echo "$IMAGE_RESULT" | jq -r '.cuda_version')
        if [ -n "$IMAGE_ID" ] && [ "$IMAGE_ID" != "null" ]; then
            check_status 0 "Image detection successful: CUDA $CUDA_VERSION ($IMAGE_ID)"
        else
            check_status 1 "Image detection returned no results"
        fi
    else
        check_status 1 "Image detection script failed"
    fi
fi

# Test subnet detection (if CLI is available and project ID is set)
if command -v nebius &> /dev/null && command -v jq &> /dev/null && [ -x "scripts/find-subnet.sh" ] && [ -f "terraform.tfvars" ]; then
    PROJECT_ID=$(grep "^parent_id" terraform.tfvars | sed 's/.*=[ ]*"\([^"]*\)".*/\1/' || echo "")
    if [ -n "$PROJECT_ID" ]; then
        print_info "Testing subnet detection for project: $PROJECT_ID"
        if SUBNET_RESULT=$(echo "{\"project_id\":\"$PROJECT_ID\"}" | scripts/find-subnet.sh 2>/dev/null); then
            SUBNET_ID=$(echo "$SUBNET_RESULT" | jq -r '.subnet_id')
            SUBNET_NAME=$(echo "$SUBNET_RESULT" | jq -r '.subnet_name')
            if [ -n "$SUBNET_ID" ] && [ "$SUBNET_ID" != "null" ]; then
                check_status 0 "Subnet detection successful: $SUBNET_NAME ($SUBNET_ID)"
            else
                check_status 1 "No subnets found. Create one with: nebius vpc v1 subnet create"
                print_info "Example: nebius vpc v1 subnet create --parent-id=$PROJECT_ID --name=default-subnet --cidr=10.0.0.0/24 --zone=eu-north1-a"
            fi
        else
            check_status 1 "Subnet detection script failed"
        fi
    fi
fi

echo ""
echo -e "${BOLD}5. Environment Variables${NC}"
echo "─────────────────────────────────────────────────────────────────"

if [ -n "$NEBIUS_TOKEN" ]; then
    check_status 0 "NEBIUS_TOKEN environment variable is set"
else
    print_warning "NEBIUS_TOKEN not set. Authentication may rely on CLI profile."
    print_info "Optional: export NEBIUS_TOKEN=your-token"
fi

echo ""
echo "═════════════════════════════════════════════════════════════════"

if [ "$ALL_CHECKS_PASSED" = true ]; then
    echo -e "${GREEN}${BOLD}✓ All checks passed! You're ready to deploy.${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. terraform init"
    echo "  2. terraform plan"
    echo "  3. terraform apply"
else
    echo -e "${RED}${BOLD}✗ Some checks failed. Please fix the issues above.${NC}"
    echo ""
    echo "Quick fixes:"
    echo "  • Install missing tools (terraform, nebius, jq)"
    echo "  • Copy terraform.tfvars.example to terraform.tfvars"
    echo "  • Set parent_id and ssh_public_key in terraform.tfvars"
    echo "  • Run: cp .terraformrc ~/.terraformrc"
    echo "  • Make scripts executable: chmod +x scripts/*.sh"
    exit 1
fi

echo "═════════════════════════════════════════════════════════════════"
