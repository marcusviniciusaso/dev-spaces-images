#!/usr/bin/env bash
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

set -euo pipefail

echo "────────────────────────────────────────────────────────────────"
echo "                       DevSpace Environment                     "
echo "────────────────────────────────────────────────────────────────"

if [ -r /usr/local/bin/fnm-common.sh ]; then
    . /usr/local/bin/fnm-common.sh
    ensure_node_state
    apply_node_target "$(read_node_target)" >/dev/null 2>&1 || true
fi

print_line() {
    local name="$1"
    local version="$2"

    if [[ -n "${version}" ]]; then
        printf "${GREEN}✔${NC} %-15s %s\n" "${name}" "${version}"
    else
        printf "${RED}✘${NC} %-15s Not Found\n" "${name}"
    fi
}

get_node_version() {
    node -v 2>/dev/null
}

get_npm_version() {
    npm -v 2>/dev/null
}

get_npx_version() {
    npx --version 2>/dev/null
}

get_selected_target() {
    cat "${NODE_CURRENT_FILE:-/home/user/.node/current}" 2>/dev/null
}

get_installed_versions() {
    local dir="${NODE_VERSION_DIR:-/opt/node/versions}"
    [ -d "$dir" ] || return 0
    find "$dir" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null \
        | sort -V | paste -sd' ' -
}

echo ""
echo "=============================================================================="
echo " DevSpaces Node Environment"
echo "=============================================================================="
echo ""

print_line "Node" "$(get_node_version)"
print_line "npm" "$(get_npm_version)"
print_line "npx" "$(get_npx_version)"
print_line "Selecionada" "$(get_selected_target)"
print_line "Instaladas" "$(get_installed_versions)"

echo ""
echo "=============================================================================="
echo -e "${YELLOW}Trocar de versão do Node:${NC}"
echo "=============================================================================="
echo ""
echo -e "${BLUE}Execute:${NC}"
echo "  nodelist          # lista as versões instaladas e a ativa"
echo "  nodeuse 22        # troca para Node 22 (aceita 22, 24 ou 25)"
echo ""
echo "=============================================================================="
echo -e "${YELLOW}IMPORTANTE: Se esta é a primeira vez, configure as credenciais:${NC}"
echo "=============================================================================="
echo ""
echo -e "${BLUE}Execute:${NC}"
echo "  devspaces-setup"
echo ""
echo -e "${YELLOW}Isso irá:${NC}"
echo ""
echo "  • Solicitar o registry npm do Artifactory"
echo "  • Configurar o .npmrc com o registry"
echo "  • Salvar configuração em persistent storage"
echo ""
