#!/usr/bin/env bash

if [ -d /home/user/persistent ] && [ -w /home/user/persistent ]; then
  export NODE_STATE_DIR="${NODE_STATE_DIR:-/home/user/persistent/.node}"
else
  export NODE_STATE_DIR="${NODE_STATE_DIR:-/home/user/.node}"
fi
export NODE_VERSION_DIR="${NODE_VERSION_DIR:-/opt/node/versions}"
export NODE_CURRENT_FILE="${NODE_CURRENT_FILE:-$NODE_STATE_DIR/current}"
export NODE_DEFAULT_MAJOR="${NODE_DEFAULT_MAJOR:-24}"

node_target_to_version() {
  case "$1" in
    22)
      echo "22.23.1"
      ;;
    24)
      echo "24.18.0"
      ;;
    25)
      echo "25.9.0"
      ;;
    *)
      return 1
      ;;
  esac
}

ensure_node_state() {
  mkdir -p "$NODE_STATE_DIR" 2>/dev/null || true
  if [ ! -f "$NODE_CURRENT_FILE" ]; then
    echo "$NODE_DEFAULT_MAJOR" > "$NODE_CURRENT_FILE" 2>/dev/null || true
  fi
}

read_node_target() {
  if [ -f "$NODE_CURRENT_FILE" ] && [ -s "$NODE_CURRENT_FILE" ]; then
    cat "$NODE_CURRENT_FILE"
    return 0
  fi

  echo "$NODE_DEFAULT_MAJOR"
}

validate_node_target() {
  case "$1" in
    22|24|25)
      return 0
      ;;
    *)
      echo "Versão inválida. Use 22, 24 ou 25." >&2
      return 1
      ;;
  esac
}

node_bin_dir_for_target() {
  local target="$1"
  local version=""

  if ! version="$(node_target_to_version "$target")"; then
    return 1
  fi

  echo "$NODE_VERSION_DIR/$version/bin"
}

apply_node_target() {
  local target="${1:-}"
  local version=""
  local node_bin_dir=""

  if [ -z "$target" ]; then
    target="$(read_node_target)"
  fi

  if ! validate_node_target "$target"; then
    return 1
  fi

  version="$(node_target_to_version "$target")"
  node_bin_dir="$(node_bin_dir_for_target "$target")"

  if [ ! -x "$node_bin_dir/node" ]; then
    echo "Node $target ($version) não encontrado em $node_bin_dir" >&2
    return 1
  fi

  # Remove qualquer versão do Node previamente prefixada no PATH antes de
  # adicionar a nova, senão trocar de volta para uma versão ja usada no mesmo
  # shell nao teria efeito.
  PATH="$(printf '%s' "$PATH" | tr ':' '\n' | grep -v "^${NODE_VERSION_DIR}/" | paste -sd: -)"
  export PATH="$node_bin_dir:$PATH"

  export NODE_CURRENT_TARGET="$target"
  export NODE_CURRENT_VERSION="$version"
  hash -r 2>/dev/null || true
}
