#!/usr/bin/env bash

set -euo pipefail

. /usr/local/bin/fnm-common.sh

TARGET="${1:-}"

if [ -z "$TARGET" ]; then
  echo "Uso: nodeuse <22|24|25>"
  exit 1
fi

validate_node_target "$TARGET"
ensure_node_state
if ! apply_node_target "$TARGET"; then
  exit 1
fi

echo "$TARGET" > "$NODE_CURRENT_FILE"

echo "Node $(node -v)"
echo "npm $(npm -v)"
