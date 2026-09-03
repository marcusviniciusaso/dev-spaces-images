#!/usr/bin/env bash

# Despacha para o pip da versao selecionada. Ver python-wrapper.sh.

set -euo pipefail

. /usr/local/bin/py-common.sh

BIN_DIR="$(python_bin_dir_for_target "$(read_python_target)")"

if [ -z "$BIN_DIR" ] || [ ! -x "$BIN_DIR/python3" ]; then
  echo "Nenhuma versão do Python instalada em $PYTHON_VERSION_DIR" >&2
  exit 1
fi

exec "$BIN_DIR/python3" -m pip "$@"
