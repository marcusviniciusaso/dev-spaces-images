#!/usr/bin/env bash

# Despacha para a versao selecionada. Existe para que processos que nao passam
# por um shell de login (VS Code server, commands do devfile) tambem respeitem a
# escolha feita com pyuse.

set -euo pipefail

. /usr/local/bin/py-common.sh

BIN_DIR="$(python_bin_dir_for_target "$(read_python_target)")"

if [ -z "$BIN_DIR" ] || [ ! -x "$BIN_DIR/python3" ]; then
  echo "Nenhuma versão do Python instalada em $PYTHON_VERSION_DIR" >&2
  exit 1
fi

exec "$BIN_DIR/python3" "$@"
