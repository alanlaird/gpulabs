#!/bin/bash
# Script to automatically find the first available subnet
# Called by Terraform's external data source

set -e

# Parse input from Terraform (JSON)
eval "$(jq -r '@sh "PROJECT_ID=\(.project_id)"')"

# Check if nebius CLI is available
if ! command -v nebius &> /dev/null; then
    echo '{"error":"nebius CLI not found. Install from https://docs.nebius.com/cli/"}' >&2
    exit 1
fi

# Fetch subnets
SUBNETS=$(nebius vpc v1 subnet list --parent-id="$PROJECT_ID" --format json 2>/dev/null)

if [ -z "$SUBNETS" ] || [ "$SUBNETS" = "null" ]; then
    echo '{"error":"Failed to fetch subnets from project '"$PROJECT_ID"'"}' >&2
    exit 1
fi

# Get the first subnet
FIRST_SUBNET=$(echo "$SUBNETS" | jq -r '.items[0]')

if [ -z "$FIRST_SUBNET" ] || [ "$FIRST_SUBNET" = "null" ]; then
    echo '{"error":"No subnets found in project '"$PROJECT_ID"'. Create one first."}' >&2
    exit 1
fi

# Return the result as JSON for Terraform
echo "$FIRST_SUBNET" | jq '{
  subnet_id: .metadata.id,
  subnet_name: .metadata.name,
  cidr: .spec.cidr
}'
