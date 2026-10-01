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

get_tool_version() {
    "$1" --version 2>/dev/null | head -n 1 | grep -oE '[0-9]+(\.[0-9]+)+' | head -n 1 || true
}

get_terraform_version() {
    local version file

    version="$(terraform version -json 2>/dev/null | jq -r '.terraform_version // empty' 2>/dev/null || true)"
    [[ -n "${version}" ]] || return 0

    file="$(tfenv version-file 2>/dev/null || true)"
    case "${file}" in
        */.terraform-version) printf '%s (%s)\n' "${version}" "${file}" ;;
        *) printf '%s (padrão do tfenv)\n' "${version}" ;;
    esac
}

get_installed_versions() {
    tfenv list 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | sort -V | paste -sd' ' - || true
}

get_go_version() {
    go env GOVERSION 2>/dev/null | awk '{sub(/^go/, "", $1); print $1}' || true
}

get_podman_version() {
    podman --version 2>/dev/null | awk '{print $3}' || true
}

get_embedded_providers() {
    find /usr/share/terraform/plugins -name 'terraform-provider-*.zip' 2>/dev/null \
        | sed -E 's|.*/terraform-provider-([^_]+)_([^_]+)_.*|\1 \2|' | sort | paste -sd',' - | sed 's/,/, /g' || true
}

echo ""
echo "=============================================================================="
echo " DevSpaces Terraform Environment"
echo "=============================================================================="
echo ""

print_line "tfenv" "$(get_tool_version tfenv)"
print_line "Terraform" "$(get_terraform_version)"
print_line "Instaladas (tfenv)" "$(get_installed_versions)"
print_line "tflint" "$(get_tool_version tflint)"
print_line "terraform-docs" "$(get_tool_version terraform-docs)"
print_line "terratest" "${TERRATEST_VERSION:-}"
print_line "Go" "$(get_go_version)"
print_line "podman" "$(get_podman_version)"
print_line "Providers embutidos" "$(get_embedded_providers)"

echo ""
echo "=============================================================================="
echo " Conectividade"
echo "=============================================================================="
echo ""

print_url "Repo Terraform" "${ARTIFACTORY_TERRAFORM_URL:-}"
print_url "Repo Go" "${ARTIFACTORY_GO_URL:-}"
print_url "Repo releases" "${ARTIFACTORY_TERRAFORM_RELEASES_URL:-}"
print_url "Terraform Registry" "https://registry.terraform.io" "/.well-known/terraform.json"

if [[ -n "${TF_CLI_CONFIG_FILE:-}" && -r "${TF_CLI_CONFIG_FILE}" ]]; then
    printf "${GREEN}✔${NC} %-20s %s\n" "Config Terraform" "${TF_CLI_CONFIG_FILE}"
else
    printf "${YELLOW}•${NC} %-20s não configurado (rode devspaces-setup)\n" "Config Terraform"
fi
printf "${GREEN}✔${NC} %-20s %s\n" "GOPROXY" "$(go env GOPROXY 2>/dev/null || true)"

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
echo "  • Solicitar o usuário e o token do Artifactory"
echo "  • Configurar o mirror de providers e o token de módulos do Terraform"
echo "  • Configurar o proxy de módulos Go usado pelo terratest"
echo "  • Configurar o tfenv para baixar outras versões do Terraform (se houver URL)"
echo "  • Salvar configuração em persistent storage"
echo ""
