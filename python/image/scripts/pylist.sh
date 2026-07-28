#!/usr/bin/env bash

set -euo pipefail

resolve_versions_dir() {
  local candidates=()

  if [ -n "${PYTHON_VERSIONS_DIR:-}" ]; then
    candidates+=("$PYTHON_VERSIONS_DIR")
  fi

  if [ -n "${PYTHON_ROOT:-}" ]; then
    candidates+=("$PYTHON_ROOT/versions")
  fi

  if [ -n "${PYTHON_DIR:-}" ]; then
    candidates+=("$PYTHON_DIR/versions")
  fi

  candidates+=("/opt/python/versions" "/home/tooling/.python/versions" "/home/user/.python/versions")

  local c
  for c in "${candidates[@]}"; do
    if [ -d "$c" ]; then
      echo "$c"
      return 0
    fi
  done

  echo ""
}

resolve_current_file() {
  local candidates=()

  if [ -n "${PYTHON_CURRENT_FILE:-}" ]; then
    candidates+=("$PYTHON_CURRENT_FILE")
  fi

  if [ -n "${PYTHON_STATE_DIR:-}" ]; then
    candidates+=("$PYTHON_STATE_DIR/current")
  fi

  if [ -n "${PYTHON_DIR:-}" ]; then
    candidates+=("$PYTHON_DIR/current")
  fi

  candidates+=("$HOME/.python/current" "/home/user/.python/current" "/home/tooling/.python/current")

  local c
  for c in "${candidates[@]}"; do
    if [ -f "$c" ]; then
      echo "$c"
      return 0
    fi
  done

  echo "${PYTHON_STATE_DIR:-$HOME/.python}/current"
}

VERSIONS_DIR="$(resolve_versions_dir)"
CURRENT_FILE="$(resolve_current_file)"

CURRENT=""
if [ -f "$CURRENT_FILE" ]; then
  CURRENT=$(cat "$CURRENT_FILE")
fi

echo ""
echo "Versões de Python disponíveis:"
echo ""

if [ -z "$VERSIONS_DIR" ]; then
  echo "Nenhuma pasta de versões encontrada."
  echo "Esperado algo como: /opt/python/versions"
  echo ""
  exit 1
fi

for v in "$VERSIONS_DIR"/*; do
  [ -d "$v" ] || continue
  v="$(basename "$v")"
  if [ "$v" = "$CURRENT" ]; then
    echo "$v (ativo)"
  else
    echo "   $v"
  fi
done

echo ""