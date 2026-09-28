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

print_line() {
    local name="$1"
    local version="$2"

    if [[ -n "${version}" ]]; then
        printf "${GREEN}✔${NC} %-20s %s\n" "${name}" "${version}"
    else
        printf "${RED}✘${NC} %-20s Not Found\n" "${name}"
    fi
}

print_url() {
    local name="$1"
    local url="$2"
    local path="${3:-}"
    local code

    if [[ -z "${url}" || "${url}" == *"<"*">"* ]]; then
        printf "${YELLOW}•${NC} %-20s não configurado\n" "${name}"
        return 0
    fi

    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "${url%/}${path}" || true)"
    if [[ "${code}" =~ ^[1-4][0-9][0-9]$ ]]; then
        printf "${GREEN}✔${NC} %-20s %s (HTTP %s)\n" "${name}" "${url}" "${code}"
    else
        printf "${RED}✘${NC} %-20s %s (HTTP %s)\n" "${name}" "${url}" "${code:-000}"
    fi
}

get_ansible_core_version() {
    ansible --version 2>/dev/null | head -n 1 | sed -E 's/.*core ([0-9.]+).*/\1/'
}

get_tool_version() {
    "$1" --version 2>/dev/null | head -n 1 | grep -oE '[0-9]+(\.[0-9]+)+' | head -n 1
}

get_python_version() {
    [ -x /opt/ansible/bin/python ] || return 0
    /opt/ansible/bin/python -V 2>&1 | awk '{print $2}'
}

get_podman_version() {
    podman --version 2>/dev/null | awk '{print $3}'
}

echo ""
echo "=============================================================================="
echo " DevSpaces Ansible Environment"
echo "=============================================================================="
echo ""

print_line "ansible-core" "$(get_ansible_core_version)"
print_line "ansible-lint" "$(get_tool_version ansible-lint)"
print_line "ansible-navigator" "$(get_tool_version ansible-navigator)"
print_line "ansible-builder" "$(get_tool_version ansible-builder)"
print_line "ansible-creator" "$(get_tool_version ansible-creator)"
print_line "molecule" "$(get_tool_version molecule)"
print_line "Python (Ansible)" "$(get_python_version)"
print_line "podman" "$(get_podman_version)"
print_line "Execution Env." "${ANSIBLE_NAVIGATOR_EXECUTION_ENVIRONMENT_IMAGE:-}"

echo ""
echo "=============================================================================="
echo " Conectividade"
echo "=============================================================================="
echo ""

print_url "Automation Platform" "${AAP_CONTROLLER_URL:-}" "/api/"
print_url "Automation Hub" "${AUTOMATION_HUB_URL:-}"

if [[ -n "${ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_URL:-}" ]]; then
    printf "${GREEN}✔${NC} %-20s %s\n" "Servidor Galaxy" "${ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_URL}"
else
    printf "${YELLOW}•${NC} %-20s não configurado (rode devspaces-setup)\n" "Servidor Galaxy"
fi

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
echo "  • Solicitar o token do Automation Hub e configurar o servidor Galaxy"
echo "  • Fazer login no registry de Execution Environments"
echo "  • Verificar o acesso ao Ansible Automation Platform"
echo "  • Salvar configuração em persistent storage"
echo ""
