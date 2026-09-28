#!/usr/bin/env bash

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo "────────────────────────────────────────────────────────────────"
echo "                    Setup DevSpace Ansible                      "
echo "────────────────────────────────────────────────────────────────"

# ================================
# BASE URLS (definidas no devfile)
# ================================
AUTOMATION_HUB_URL="${AUTOMATION_HUB_URL:-https://<AUTOMATION_HUB_URL>}"
AUTOMATION_HUB_AUTH_URL="${AUTOMATION_HUB_AUTH_URL:-}"
AUTOMATION_HUB_REGISTRY="${AUTOMATION_HUB_REGISTRY:-}"
AAP_CONTROLLER_URL="${AAP_CONTROLLER_URL:-https://<AAP_CONTROLLER_URL>}"

# ================================
# DESTINOS
# ================================
if [ -d /home/user/persistent ] && [ -w /home/user/persistent ]; then
  ANSIBLE_HOME="${ANSIBLE_HOME:-/home/user/persistent/.ansible}"
  REGISTRY_AUTH_FILE="${REGISTRY_AUTH_FILE:-/home/user/persistent/.config/containers/auth.json}"
else
  ANSIBLE_HOME="${ANSIBLE_HOME:-$HOME/.ansible}"
  REGISTRY_AUTH_FILE="${REGISTRY_AUTH_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/containers/auth.json}"
fi
GALAXY_ENV_FILE="${ANSIBLE_HOME}/galaxy.env"

# ================================
# HELPERS
# ================================
is_placeholder() {
  [[ -z "$1" || "$1" == *"<"*">"* ]]
}

host_of() {
  printf '%s' "$1" | sed -E 's|^https?://||; s|/.*$||'
}

# ================================
# 1. AUTOMATION HUB (COLLECTIONS)
# ================================
echo ""
echo -e "${YELLOW}[1/3] Automation Hub — collections${NC}"

if is_placeholder "${AUTOMATION_HUB_URL}"; then
  echo ""
  echo -e "${RED}A URL do Automation Hub ainda contem um placeholder:${NC}"
  echo -e "${BLUE}${AUTOMATION_HUB_URL}${NC}"
  echo ""
  echo -e "${YELLOW}Defina AUTOMATION_HUB_URL no devfile e rode novamente.${NC}"
  echo -e "${YELLOW}Nenhuma credencial foi solicitada ou gravada.${NC}"
  exit 1
fi

HUB_BASE="${AUTOMATION_HUB_URL%/}"
if [[ "${HUB_BASE}" == */api/* || "${HUB_BASE}" == */api ]]; then
  GALAXY_SERVER_URL="${HUB_BASE}/"
else
  GALAXY_SERVER_URL="${HUB_BASE}/api/galaxy/content/published/"
fi

read -r -s -p "Informe o token do Automation Hub: " HUB_TOKEN
echo ""
[[ -z "${HUB_TOKEN}" ]] && { echo -e "${RED}Token obrigatório${NC}"; exit 1; }

mkdir -p "${ANSIBLE_HOME}"
if [[ -f "${GALAXY_ENV_FILE}" ]]; then
  cp "${GALAXY_ENV_FILE}" "${GALAXY_ENV_FILE}.bak"
  chmod 600 "${GALAXY_ENV_FILE}.bak" 2>/dev/null || true
fi

tmp_file="$(mktemp "${ANSIBLE_HOME}/galaxy.env.tmp.XXXXXX")"
chmod 600 "${tmp_file}"
{
  echo "# Gerado por devspaces-setup — servidor Galaxy do Automation Hub"
  printf 'export ANSIBLE_GALAXY_SERVER_LIST=%q\n' "automation_hub"
  printf 'export ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_URL=%q\n' "${GALAXY_SERVER_URL}"
  printf 'export ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN=%q\n' "${HUB_TOKEN}"
  if [[ -n "${AUTOMATION_HUB_AUTH_URL}" ]]; then
    printf 'export ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_AUTH_URL=%q\n' "${AUTOMATION_HUB_AUTH_URL}"
  fi
} > "${tmp_file}"
mv -f "${tmp_file}" "${GALAXY_ENV_FILE}"
chmod 600 "${GALAXY_ENV_FILE}"

echo -e "${GREEN}✔${NC} Servidor Galaxy configurado: ${BLUE}${GALAXY_SERVER_URL}${NC}"

# ================================
# 2. REGISTRY DE EXECUTION ENVIRONMENTS
# ================================
echo ""
echo -e "${YELLOW}[2/3] Registry de Execution Environments${NC}"

# O registry do Private Automation Hub fica no mesmo host da UI.
if is_placeholder "${AUTOMATION_HUB_REGISTRY}"; then
  AUTOMATION_HUB_REGISTRY="$(host_of "${AUTOMATION_HUB_URL}")"
fi

read -r -p "Registry [${AUTOMATION_HUB_REGISTRY}]: " INPUT_REGISTRY
AUTOMATION_HUB_REGISTRY="${INPUT_REGISTRY:-$AUTOMATION_HUB_REGISTRY}"

read -r -p "Usuário do registry: " REGISTRY_USERNAME
[[ -z "${REGISTRY_USERNAME}" ]] && { echo -e "${RED}Usuário obrigatório${NC}"; exit 1; }

read -r -s -p "Senha/token do registry: " REGISTRY_PASSWORD
echo ""
[[ -z "${REGISTRY_PASSWORD}" ]] && { echo -e "${RED}Senha obrigatória${NC}"; exit 1; }

mkdir -p "$(dirname "${REGISTRY_AUTH_FILE}")"
if printf '%s' "${REGISTRY_PASSWORD}" | podman login \
     --authfile "${REGISTRY_AUTH_FILE}" \
     --username "${REGISTRY_USERNAME}" \
     --password-stdin \
     "${AUTOMATION_HUB_REGISTRY}" >/dev/null; then
  chmod 600 "${REGISTRY_AUTH_FILE}" 2>/dev/null || true
  echo -e "${GREEN}✔${NC} Login no registry ${BLUE}${AUTOMATION_HUB_REGISTRY}${NC} salvo em ${BLUE}${REGISTRY_AUTH_FILE}${NC}"
else
  echo -e "${RED}✘ Falha no login em ${AUTOMATION_HUB_REGISTRY}${NC}"
  echo -e "${YELLOW}A configuração do Galaxy foi mantida. Rode devspaces-setup novamente para tentar o login.${NC}"
fi

# ================================
# 3. ANSIBLE AUTOMATION PLATFORM
# ================================
echo ""
echo -e "${YELLOW}[3/3] Ansible Automation Platform${NC}"

if is_placeholder "${AAP_CONTROLLER_URL}"; then
  echo -e "${YELLOW}AAP_CONTROLLER_URL não configurada no devfile — verificação ignorada.${NC}"
else
  AAP_STATUS="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "${AAP_CONTROLLER_URL%/}/api/" || true)"
  if [[ "${AAP_STATUS}" =~ ^[1-4][0-9][0-9]$ ]]; then
    echo -e "${GREEN}✔${NC} AAP acessível: ${BLUE}${AAP_CONTROLLER_URL}${NC} (HTTP ${AAP_STATUS})"
  else
    echo -e "${RED}✘${NC} AAP inacessível: ${BLUE}${AAP_CONTROLLER_URL}${NC} (HTTP ${AAP_STATUS:-000})"
  fi
fi

# ================================
# FINAL
# ================================
echo ""
echo -e "${GREEN}Setup finalizado com sucesso${NC}"
echo -e "${YELLOW}Configuração do Galaxy:${NC} ${BLUE}${GALAXY_ENV_FILE}${NC}"
echo ""
echo -e "${YELLOW}Abra um novo terminal (ou rode ${BLUE}source ~/.bashrc${YELLOW}) e valide com:${NC}"
echo -e "${BLUE}ansible-galaxy collection install -r requirements.yml${NC}"
echo -e "${BLUE}ansible-galaxy collection list${NC}"
echo -e "${BLUE}ansible-navigator run playbooks/site.yml --ee true${NC}"
