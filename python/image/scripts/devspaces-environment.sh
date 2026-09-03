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

if [ -r /usr/local/bin/py-common.sh ]; then
    . /usr/local/bin/py-common.sh
    ensure_python_state
    apply_python_target "$(read_python_target)" >/dev/null 2>&1 || true
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

get_python_version() {
    python3 -V 2>&1 | awk '{print $2}'
}

get_pip_version() {
    pip3 -V 2>/dev/null | awk '{print $2}'
}

get_venv_status() {
    python3 -c 'import venv' >/dev/null 2>&1 && echo "disponível"
}

get_selected_target() {
    cat "${PYTHON_CURRENT_FILE:-/home/user/.python/current}" 2>/dev/null
}

get_installed_versions() {
    local dir="${PYTHON_VERSION_DIR:-/opt/python/versions}"
    [ -d "$dir" ] || return 0
    find "$dir" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null \
        | sort -V | paste -sd' ' -
}

echo ""
echo "=============================================================================="
echo " DevSpaces Python Environment"
echo "=============================================================================="
echo ""

print_line "Python" "$(get_python_version)"
print_line "pip" "$(get_pip_version)"
print_line "venv" "$(get_venv_status)"
print_line "Selecionada" "$(get_selected_target)"
print_line "Instaladas" "$(get_installed_versions)"

echo ""
echo "=============================================================================="
echo -e "${YELLOW}Trocar de versão do Python:${NC}"
echo "=============================================================================="
echo ""
echo -e "${BLUE}Execute:${NC}"
echo "  pylist            # lista as versões instaladas e a ativa"
echo "  pyuse 3.13        # troca para Python 3.13 (aceita 3.9, 3.12, 3.13 ou 3.14)"
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
echo "  • Solicitar usuário e senha/token do Artifactory"
echo "  • Configurar o pip.conf com o índice PyPI"
echo "  • Salvar configuração em persistent storage"
echo ""
