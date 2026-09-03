#!/usr/bin/env bash

export PYTHON_ROOT="${PYTHON_ROOT:-/opt/python}"
export PYTHON_VERSION_DIR="${PYTHON_VERSION_DIR:-$PYTHON_ROOT/versions}"

if [ -d /home/user/persistent ] && [ -w /home/user/persistent ]; then
  export PYTHON_STATE_DIR="${PYTHON_STATE_DIR:-/home/user/persistent/.python}"
else
  export PYTHON_STATE_DIR="${PYTHON_STATE_DIR:-/home/user/.python}"
fi
export PYTHON_CURRENT_FILE="${PYTHON_CURRENT_FILE:-$PYTHON_STATE_DIR/current}"
export PYTHON_DEFAULT_MINOR="${PYTHON_DEFAULT_MINOR:-3.12}"

# Lista os minors instalados (3.9, 3.12, ...) derivando de $PYTHON_VERSION_DIR.
# Nada e hardcoded: o micro entregue pelo gerenciador de pacotes muda entre
# rebuilds da imagem base e precisa ser descoberto em runtime.
python_installed_targets() {
  local dir version

  [ -d "$PYTHON_VERSION_DIR" ] || return 0

  for dir in "$PYTHON_VERSION_DIR"/*/; do
    [ -d "$dir" ] || continue
    version="$(basename "$dir")"
    printf '%s\n' "${version%.*}"
  done | sort -V -u
}

# Resolve minor -> versao completa instalada. Se houver mais de um micro do
# mesmo minor, vence o maior.
python_target_to_version() {
  local target="$1"
  local dir version match=""

  [ -n "$target" ] || return 1
  [ -d "$PYTHON_VERSION_DIR" ] || return 1

  for dir in "$PYTHON_VERSION_DIR"/*/; do
    [ -d "$dir" ] || continue
    version="$(basename "$dir")"
    if [ "${version%.*}" = "$target" ]; then
      match="$(printf '%s\n%s\n' "$match" "$version" | sort -V | tail -n 1)"
    fi
  done

  [ -n "$match" ] || return 1
  printf '%s\n' "$match"
}

ensure_python_state() {
  mkdir -p "$PYTHON_STATE_DIR" 2>/dev/null || true
  if [ ! -f "$PYTHON_CURRENT_FILE" ] || [ ! -s "$PYTHON_CURRENT_FILE" ]; then
    echo "$PYTHON_DEFAULT_MINOR" > "$PYTHON_CURRENT_FILE" 2>/dev/null || true
  fi
}

# O arquivo de estado guarda o MINOR (3.12), nunca a versao completa: um micro
# gravado no volume persistente deixaria de existir apos um rebuild da imagem.
read_python_target() {
  local target=""

  if [ -f "$PYTHON_CURRENT_FILE" ] && [ -s "$PYTHON_CURRENT_FILE" ]; then
    target="$(head -n 1 "$PYTHON_CURRENT_FILE" | tr -d '[:space:]')"
    # Tolera arquivos de estado antigos que guardavam a versao completa.
    case "$target" in
      *.*.*) target="${target%.*}" ;;
    esac
  fi

  if [ -n "$target" ] && python_target_to_version "$target" >/dev/null 2>&1; then
    printf '%s\n' "$target"
    return 0
  fi

  printf '%s\n' "$PYTHON_DEFAULT_MINOR"
}

validate_python_target() {
  local target="$1"

  if python_target_to_version "$target" >/dev/null 2>&1; then
    return 0
  fi

  echo "Versão inválida: ${target:-<vazio>}. Use uma de: $(python_installed_targets | paste -sd' ' -)" >&2
  return 1
}

python_bin_dir_for_target() {
  local target="$1"
  local version=""

  if ! version="$(python_target_to_version "$target")"; then
    return 1
  fi

  printf '%s\n' "$PYTHON_VERSION_DIR/$version/bin"
}

apply_python_target() {
  local target="${1:-}"
  local version=""
  local python_bin_dir=""

  if [ -z "$target" ]; then
    target="$(read_python_target)"
  fi

  if ! validate_python_target "$target"; then
    return 1
  fi

  version="$(python_target_to_version "$target")"
  python_bin_dir="$(python_bin_dir_for_target "$target")"

  if [ ! -x "$python_bin_dir/python3" ]; then
    echo "Python $target ($version) não encontrado em $python_bin_dir" >&2
    return 1
  fi

  # Remove qualquer entrada do Python previamente prefixada no PATH antes de
  # adicionar a nova, senão trocar de volta para uma versão ja usada no mesmo
  # shell nao teria efeito. O filtro usa $PYTHON_ROOT/ para limpar tambem
  # $PYTHON_ROOT/default/bin, que o ENV da imagem acrescenta ao fim do PATH.
  PATH="$(printf '%s' "$PATH" | tr ':' '\n' | grep -v "^${PYTHON_ROOT}/" | paste -sd: -)"
  export PATH="$python_bin_dir:$PATH"

  export PYTHON_CURRENT_TARGET="$target"
  export PYTHON_CURRENT_VERSION="$version"
  hash -r 2>/dev/null || true
}
