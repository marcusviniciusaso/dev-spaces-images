#!/usr/bin/env bash

set -euo pipefail

. /usr/local/bin/py-common.sh

TARGET="${1:-}"

if [ -z "$TARGET" ]; then
  echo "Uso: pyuse <$(python_installed_targets | paste -sd'|' -)>"
  exit 1
fi

validate_python_target "$TARGET"
ensure_python_state
if ! apply_python_target "$TARGET"; then
  exit 1
fi

echo "$TARGET" > "$PYTHON_CURRENT_FILE"

echo "Python $(python3 -V 2>&1 | awk '{print $2}')"
echo "pip $(pip3 -V 2>/dev/null | awk '{print $2}')"
