#!/usr/bin/env bash
set -euxo pipefail

backend="podman"

img="$($backend images --format "{{ .Repository }}:{{ .Tag }}" | head -n1)"

$backend tag "$img" "$@"

$backend images
