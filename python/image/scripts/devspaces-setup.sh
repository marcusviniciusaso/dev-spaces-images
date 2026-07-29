#!/usr/bin/env bash

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo
echo "────────────────────────────────────────────────────────────────"
echo "                Setup DevSpace - Python / pip                  "
echo "────────────────────────────────────────────────────────────────"
echo

# Variáveis de ambiente (Nexus)
NEXUS_PYPI_BASEURL="${NEXUS_PYPI_BASEURL:-https://<NEXUSREPOSITORY>:<PORT>/repository/public-pypi-central}"
PIP_HOME_DIR="${PIP_HOME_DIR:-/home/user}"
PERSISTENT_PIP_HOME="${PERSISTENT_PIP_HOME:-/home/user/persistent}"

echo
echo -e "${BLUE}Autenticando no Nexus (pip)${NC}"

read -p "Usuário Nexus: " PIP_USER
read -s -p "Senha Nexus: " PIP_PASS
echo


# Montando URL com credenciais
NEXUS_HOST=$(echo "$NEXUS_PYPI_BASEURL" | sed -E 's|https?://||')

AUTH_URL="https://${PIP_USER}:${PIP_PASS}@${NEXUS_HOST}/simple"

write_pip_config() {
	local target_home="$1"
	local target_dir="${target_home}/.pip"
	local target_file="${target_dir}/pip.conf"

	mkdir -p "$target_dir"
	cat > "$target_file" <<EOF
[global]
index-url = ${AUTH_URL}
trusted-host = $(echo "$NEXUS_HOST" | cut -d/ -f1)
timeout = 60
disable-pip-version-check = true

[install]
no-cache-dir = false
EOF
}

write_pip_config "$PIP_HOME_DIR"

if [[ -d "$PERSISTENT_PIP_HOME" && "$PERSISTENT_PIP_HOME" != "$PIP_HOME_DIR" ]]; then
	write_pip_config "$PERSISTENT_PIP_HOME"
fi

echo -e "${GREEN}pip configurado com sucesso!${NC}"