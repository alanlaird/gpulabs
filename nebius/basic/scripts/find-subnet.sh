#!/bin/bash
# Find the first available subnet — called by Terraform external data source
set -e

eval "$(jq -r '@sh "PROJECT_ID=\(.project_id)"')"

if ! command -v nebius &>/dev/null; then
    echo '{"error":"nebius CLI not found"}' >&2
    exit 1
fi

SUBNETS=$(nebius vpc v1 subnet list --parent-id="$PROJECT_ID" --format json 2>/dev/null)

if [ -z "$SUBNETS" ] || [ "$SUBNETS" = "null" ]; then
    echo '{"error":"Failed to fetch subnets from project '"$PROJECT_ID"'"}' >&2
    exit 1
fi

FIRST=$(echo "$SUBNETS" | jq -r '.items[0]')

if [ -z "$FIRST" ] || [ "$FIRST" = "null" ]; then
    echo '{"error":"No subnets found in project '"$PROJECT_ID"'"}' >&2
    exit 1
fi

echo "$FIRST" | jq '{
  subnet_id:   .metadata.id,
  subnet_name: .metadata.name,
  cidr:        .spec.cidr
}'
