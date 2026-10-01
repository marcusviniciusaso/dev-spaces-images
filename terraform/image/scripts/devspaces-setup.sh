#!/usr/bin/env bash

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo "────────────────────────────────────────────────────────────────"
echo "                    Setup DevSpace Terraform                    "
echo "────────────────────────────────────────────────────────────────"

# ================================
# BASE URLS (definidas no devfile)
# ================================
ARTIFACTORY_TERRAFORM_URL="${ARTIFACTORY_TERRAFORM_URL:-https://<ARTIFACTORY_TERRAFORM_URL>}"
ARTIFACTORY_GO_URL="${ARTIFACTORY_GO_URL:-https://<ARTIFACTORY_GO_URL>}"
ARTIFACTORY_TERRAFORM_RELEASES_URL="${ARTIFACTORY_TERRAFORM_RELEASES_URL:-}"

# ================================
# DESTINOS
# ================================
if [ -d /home/user/persistent ] && [ -w /home/user/persistent ]; then
  TERRAFORM_STATE_DIR="/home/user/persistent/.terraform.d"
else
  TERRAFORM_STATE_DIR="$HOME/.terraform.d"
fi
NETRC_FILE="${TERRAFORM_STATE_DIR}/.netrc"
TERRAFORM_RC_FILE="${TERRAFORM_STATE_DIR}/terraform.rc"
ENV_FILE="${TERRAFORM_STATE_DIR}/devspaces.env"

PROVIDER_MIRROR_DIR="/usr/share/terraform/plugins"
GO_LOCAL_PROXY="file:///opt/terratest/goproxy"

# ================================
# HELPERS
# ================================
is_placeholder() {
  [[ -z "$1" || "$1" == *"<"*">"* ]]
}

host_of() {
  printf '%s' "$1" | sed -E 's|^https?://||; s|/.*$||; s|:[0-9]+$||'
}

write_secure_file() {
  local target="$1"
  local target_dir tmp_file

  target_dir="$(dirname "${target}")"
  mkdir -p "${target_dir}"

  if [[ -f "${target}" ]]; then
    cp "${target}" "${target}.bak"
    chmod 600 "${target}.bak" 2>/dev/null || true
  fi

  tmp_file="$(mktemp "${target_dir}/.$(basename "${target}").tmp.XXXXXX")"
  chmod 600 "${tmp_file}"
  cat > "${tmp_file}"
  mv -f "${tmp_file}" "${target}"
  chmod 600 "${target}"
}

check_url() {
  local name="$1"
  local url="$2"
  local code

  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 --netrc-file "${NETRC_FILE}" "${url}" || true)"
  case "${code}" in
    2??|3??)
      echo -e "${GREEN}✔${NC} ${name}: ${BLUE}${url}${NC} (HTTP ${code})" ;;
    401|403)
      echo -e "${RED}✘${NC} ${name}: credenciais recusadas em ${BLUE}${url}${NC} (HTTP ${code})" ;;
    4??)
      echo -e "${YELLOW}•${NC} ${name}: acessível, mas ${BLUE}${url}${NC} respondeu HTTP ${code} — confira a URL no devfile" ;;
    *)
      echo -e "${RED}✘${NC} ${name}: inacessível ${BLUE}${url}${NC} (HTTP ${code:-000})" ;;
  esac
}

# ================================
# GUARDA DE PLACEHOLDER
# ================================
TF_CONFIGURED=0; GO_CONFIGURED=0; RELEASES_CONFIGURED=0
is_placeholder "${ARTIFACTORY_TERRAFORM_URL}" || TF_CONFIGURED=1
is_placeholder "${ARTIFACTORY_GO_URL}" || GO_CONFIGURED=1
is_placeholder "${ARTIFACTORY_TERRAFORM_RELEASES_URL}" || RELEASES_CONFIGURED=1

if (( TF_CONFIGURED + GO_CONFIGURED + RELEASES_CONFIGURED == 0 )); then
  echo ""
  echo -e "${RED}Nenhuma URL do repositório corporativo foi configurada:${NC}"
  echo -e "  ARTIFACTORY_TERRAFORM_URL          = ${BLUE}${ARTIFACTORY_TERRAFORM_URL}${NC}"
  echo -e "  ARTIFACTORY_GO_URL                 = ${BLUE}${ARTIFACTORY_GO_URL}${NC}"
  echo -e "  ARTIFACTORY_TERRAFORM_RELEASES_URL = ${BLUE}${ARTIFACTORY_TERRAFORM_RELEASES_URL:-<vazio>}${NC}"
  echo ""
  echo -e "${YELLOW}Defina ao menos uma delas no devfile e rode novamente.${NC}"
  echo -e "${YELLOW}Nenhuma credencial foi solicitada ou gravada.${NC}"
  exit 1
fi

# ================================
# 1. CREDENCIAIS
# ================================
echo ""
echo -e "${YELLOW}[1/4] Credenciais do repositório${NC}"

read -r -p "Informe o usuário do Artifactory: " ARTIFACTORY_USERNAME
[[ -z "${ARTIFACTORY_USERNAME}" ]] && { echo -e "${RED}Usuário obrigatório${NC}"; exit 1; }

read -r -s -p "Informe o token (Identity/Reference Token) do Artifactory: " ARTIFACTORY_TOKEN
echo ""
[[ -z "${ARTIFACTORY_TOKEN}" ]] && { echo -e "${RED}Token obrigatório${NC}"; exit 1; }

HOSTS=()
(( TF_CONFIGURED )) && HOSTS+=("$(host_of "${ARTIFACTORY_TERRAFORM_URL}")")
(( GO_CONFIGURED )) && HOSTS+=("$(host_of "${ARTIFACTORY_GO_URL}")")
(( RELEASES_CONFIGURED )) && HOSTS+=("$(host_of "${ARTIFACTORY_TERRAFORM_RELEASES_URL}")")

printf '%s\n' "${HOSTS[@]}" | sort -u | while read -r host; do
  printf 'machine %s login %s password %s\n' "${host}" "${ARTIFACTORY_USERNAME}" "${ARTIFACTORY_TOKEN}"
done | write_secure_file "${NETRC_FILE}"

echo -e "${GREEN}✔${NC} Credenciais gravadas em ${BLUE}${NETRC_FILE}${NC}"

ENV_LINES=()
ENV_LINES+=("$(printf 'export NETRC=%q' "${NETRC_FILE}")")

# ================================
# 2. TERRAFORM (PROVIDERS E MÓDULOS)
# ================================
echo ""
echo -e "${YELLOW}[2/4] Terraform — providers e módulos${NC}"

TF_MIRROR_URL=""
if (( TF_CONFIGURED )); then
  TF_BASE="${ARTIFACTORY_TERRAFORM_URL%/}"
  TF_BASE="${TF_BASE%/providers}"
  TF_MIRROR_URL="${TF_BASE}/providers/"
  TF_HOST="$(host_of "${ARTIFACTORY_TERRAFORM_URL}")"
  TF_TOKEN_VAR="TF_TOKEN_$(printf '%s' "${TF_HOST}" | sed -e 's/-/__/g' -e 's/\./_/g')"

  EMBEDDED_PROVIDERS="$(cd "${PROVIDER_MIRROR_DIR}" 2>/dev/null \
    && find . -mindepth 3 -maxdepth 3 -type d | sed 's|^\./||' | sort \
    | sed 's/.*/"&"/' | paste -sd, - | sed 's/,/, /g' || true)"

  {
    echo "# Gerado por devspaces-setup"
    echo "provider_installation {"
    if [[ -n "${EMBEDDED_PROVIDERS}" ]]; then
      echo "  filesystem_mirror {"
      echo "    path    = \"${PROVIDER_MIRROR_DIR}\""
      echo "    include = [${EMBEDDED_PROVIDERS}]"
      echo "  }"
    fi
    echo "  network_mirror {"
    echo "    url     = \"${TF_MIRROR_URL}\""
    [[ -n "${EMBEDDED_PROVIDERS}" ]] && echo "    exclude = [${EMBEDDED_PROVIDERS}]"
    echo "  }"
    echo "}"
  } | write_secure_file "${TERRAFORM_RC_FILE}"

  ENV_LINES+=("$(printf 'export TF_CLI_CONFIG_FILE=%q' "${TERRAFORM_RC_FILE}")")
  ENV_LINES+=("$(printf 'export %s=%q' "${TF_TOKEN_VAR}" "${ARTIFACTORY_TOKEN}")")

  echo -e "${GREEN}✔${NC} Mirror de providers: ${BLUE}${TF_MIRROR_URL}${NC}"
  echo -e "${GREEN}✔${NC} Token de módulos em ${BLUE}${TF_TOKEN_VAR}${NC}"
else
  echo -e "${YELLOW}ARTIFACTORY_TERRAFORM_URL não configurada — os providers vêm do registry público.${NC}"
fi

# ================================
# 3. GO (TERRATEST)
# ================================
echo ""
echo -e "${YELLOW}[3/4] Go — módulos do terratest${NC}"

if (( GO_CONFIGURED )); then
  GO_URL="${ARTIFACTORY_GO_URL%/}"
  ENV_LINES+=("$(printf 'export GOPROXY=%q' "${GO_LOCAL_PROXY},${GO_URL}")")
  echo -e "${GREEN}✔${NC} GOPROXY: ${BLUE}${GO_LOCAL_PROXY},${GO_URL}${NC}"
else
  echo -e "${YELLOW}ARTIFACTORY_GO_URL não configurada — mantido o GOPROXY da imagem.${NC}"
fi

# ================================
# 4. TFENV (RELEASES DO TERRAFORM)
# ================================
echo ""
echo -e "${YELLOW}[4/4] tfenv — releases do Terraform${NC}"

if (( RELEASES_CONFIGURED )); then
  RELEASES_URL="${ARTIFACTORY_TERRAFORM_RELEASES_URL%/}"
  ENV_LINES+=("$(printf 'export TFENV_REMOTE=%q' "${RELEASES_URL}")")
  ENV_LINES+=("$(printf 'export TFENV_NETRC_PATH=%q' "${NETRC_FILE}")")
  echo -e "${GREEN}✔${NC} TFENV_REMOTE: ${BLUE}${RELEASES_URL}${NC}"
else
  echo -e "${YELLOW}ARTIFACTORY_TERRAFORM_RELEASES_URL não configurada — use as versões já instaladas (tfenv list).${NC}"
fi

{
  echo "# Gerado por devspaces-setup — repositório corporativo (Terraform, Go, tfenv)"
  printf '%s\n' "${ENV_LINES[@]}"
} | write_secure_file "${ENV_FILE}"

# ================================
# VERIFICAÇÃO
# ================================
echo ""
echo -e "${YELLOW}Verificando o acesso com as credenciais informadas${NC}"
(( TF_CONFIGURED )) && check_url "Terraform" "${TF_MIRROR_URL}registry.terraform.io/hashicorp/random/index.json"
(( GO_CONFIGURED )) && check_url "Go" "${GO_URL}/github.com/stretchr/testify/@v/list"
(( RELEASES_CONFIGURED )) && check_url "Releases" "${RELEASES_URL}/terraform/"

# ================================
# FINAL
# ================================
echo ""
echo -e "${GREEN}Setup finalizado com sucesso${NC}"
echo -e "${YELLOW}Configuração:${NC} ${BLUE}${ENV_FILE}${NC}"
echo ""
echo -e "${YELLOW}Abra um novo terminal (ou rode ${BLUE}source ~/.bashrc${YELLOW}) e valide com:${NC}"
(( TF_CONFIGURED )) && echo -e "${BLUE}terraform init${NC}                     # no diretório do seu projeto"
(( GO_CONFIGURED )) && echo -e "${BLUE}go mod download${NC}                    # no diretório dos testes (go.mod)"
(( RELEASES_CONFIGURED )) && echo -e "${BLUE}tfenv list-remote | head${NC}"
exit 0
