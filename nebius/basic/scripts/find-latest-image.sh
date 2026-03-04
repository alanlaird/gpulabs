#!/bin/bash
# Find the latest Ubuntu CUDA GPU image — called by Terraform external data source
set -e

eval "$(jq -r '@sh "REGION=\(.region)"')"

if ! command -v nebius &>/dev/null; then
    echo '{"error":"nebius CLI not found"}' >&2
    exit 1
fi

IMAGES=$(nebius compute image list-public --region "$REGION" --format json 2>/dev/null)

if [ -z "$IMAGES" ] || [ "$IMAGES" = "null" ]; then
    echo '{"error":"Failed to fetch images from region '"$REGION"'"}' >&2
    exit 1
fi

BEST=$(echo "$IMAGES" | jq -r '
  .items[]
  | select(
      (.metadata.labels.os_name // "" | test("Ubuntu"; "i")) and
      (.metadata.labels.cuda_toolkit // "" != "")
    )
  | {
      id:           .metadata.id,
      name:         .metadata.name,
      os_version:   (.metadata.labels.os_version // "unknown"),
      cuda_version: (.metadata.labels.cuda_toolkit // "0"),
      gpu_drivers:  (.metadata.labels.nvidia_gpu_drivers // "unknown")
    }
  | . + {cuda_numeric: (.cuda_version | split(".") | map(tonumber) | .[0] * 100 + .[1])}
' | jq -s 'sort_by(-.cuda_numeric) | .[0]')

if [ -z "$BEST" ] || [ "$BEST" = "null" ]; then
    echo '{"error":"No Ubuntu CUDA images found in region '"$REGION"'"}' >&2
    exit 1
fi

echo "$BEST" | jq '{
  image_id:     .id,
  image_name:   .name,
  os_version:   .os_version,
  cuda_version: .cuda_version,
  gpu_drivers:  .gpu_drivers
}'
