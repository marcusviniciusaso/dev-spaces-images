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

show_help() {
  local vdir="$(resolve_versions_dir)"
  echo "Uso: pyuse <major.minor>"
  if [ -n "$vdir" ] && [ -d "$vdir" ]; then
    echo ""
    echo "Versões disponíveis:"
    for d in "$vdir"/*/; do
      [ -d "$d" ] || continue
      local v="$(basename "$d")"
      local short="${v%.*}"
      echo "  $short  ($v)"
    done
  fi
}

TARGET="${1:-}"
if [ -z "$TARGET" ]; then
  show_help
  exit 1
fi

VERSIONS_DIR="$(resolve_versions_dir)"
CURRENT_FILE="$(resolve_current_file)"

if [ -z "$VERSIONS_DIR" ]; then
  echo "Nenhuma pasta de versões encontrada."
  echo "Esperado algo como: /opt/python/versions"
  exit 1
fi

CURRENT_DIR="$(dirname "$CURRENT_FILE")"
mkdir -p "$CURRENT_DIR"

NEW_VERSION=""
for d in "$VERSIONS_DIR"/*/; do
  [ -d "$d" ] || continue
  v="$(basename "$d")"
  short="${v%.*}"
  if [ "$short" = "$TARGET" ]; then
    NEW_VERSION="$v"
    break
  fi
done

if [ -z "$NEW_VERSION" ]; then
  echo "Versão inválida: $TARGET"
  show_help
  exit 1
fi

if [ ! -x "$VERSIONS_DIR/$NEW_VERSION/bin/python3" ]; then
  echo "Versão não instalada nesta imagem: $NEW_VERSION"
  exit 1
fi

echo "$NEW_VERSION" > "$CURRENT_FILE"
echo "Python $(cat "$CURRENT_FILE")"