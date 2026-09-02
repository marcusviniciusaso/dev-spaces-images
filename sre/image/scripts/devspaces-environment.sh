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
        printf "${GREEN}✔${NC} %-15s %s\n" "${name}" "${version}"
    else
        printf "${RED}✘${NC} %-15s Not Found\n" "${name}"
    fi
}

get_oc_version() {
    oc version --client 2>/dev/null | head -n 1
}

get_kubectl_version() {
    kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null | head -n 1
}

get_helm_version() {
    helm version --short 2>/dev/null
}

echo ""
echo "=============================================================================="
echo " DevSpaces SRE Environment"
echo "=============================================================================="
echo ""

print_line "oc" "$(get_oc_version)"
print_line "kubectl" "$(get_kubectl_version)"
print_line "helm" "$(get_helm_version)"

echo ""
echo "=============================================================================="
echo -e "${YELLOW}IMPORTANTE: Se esta é a primeira vez, configure o repositório YUM:${NC}"
echo "=============================================================================="
echo ""
echo -e "${BLUE}Execute:${NC}"
echo "  devspaces-setup"
echo ""
echo -e "${YELLOW}Isso irá:${NC}"
echo "  • Configurar repositório YUM com URL do Artifactory"
echo "  • Salvar configuração no sistema"
echo ""
