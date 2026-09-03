#!/usr/bin/env bash

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo "────────────────────────────────────────────────────────────────"
echo "                       Setup DevSpace                           "
echo "────────────────────────────────────────────────────────────────"

# ================================
# BASE URL
# ================================
ARTIFACTORY_NPM_BASEURL="${ARTIFACTORY_NPM_BASEURL:-https://<ARTIFACTORY_URL>/artifactory/public-npm-central/}"
NPM_SCOPE="${NPM_SCOPE:-}"

if ! command -v npm >/dev/null 2>&1; then
  echo -e "${RED}npm nao encontrado no PATH${NC}"
  exit 1
fi

# ================================
# DESTINOS DO .NPMRC
# ================================
if [ -d /home/user/persistent ] && [ -w /home/user/persistent ]; then
  NPM_HOME_DIR="${NPM_HOME_DIR:-/home/user/persistent}"
else
  NPM_HOME_DIR="${NPM_HOME_DIR:-${HOME}}"
fi
PERSISTENT_NPM_HOME="${PERSISTENT_NPM_HOME:-/home/user/persistent}"

write_npmrc_file() {
  local target_home="$1"
  local target_file="${target_home}/.npmrc"
  local tmp_file

  mkdir -p "${target_home}"

  if [[ -f "${target_file}" ]]; then
    cp "${target_file}" "${target_file}.bak"
  fi

  tmp_file="$(mktemp "${target_home}/.npmrc.tmp.XXXXXX")"

  cat > "${tmp_file}" <<EOF
registry=${ARTIFACTORY_NPM_BASEURL}
EOF

  mv -f "${tmp_file}" "${target_file}"
}

# ================================
# ESCREVE .NPMRC
# ================================
write_npmrc_file "${NPM_HOME_DIR}"

if [[ -d "${PERSISTENT_NPM_HOME}" && "${PERSISTENT_NPM_HOME}" != "${NPM_HOME_DIR}" ]]; then
  write_npmrc_file "${PERSISTENT_NPM_HOME}"
fi

export NPM_CONFIG_USERCONFIG="${NPM_HOME_DIR}/.npmrc"

echo ""
echo -e "${YELLOW}Registry configurado:${NC} ${BLUE}${ARTIFACTORY_NPM_BASEURL}${NC}"

# ================================
# LOGIN
# ================================
if [[ "${ARTIFACTORY_NPM_BASEURL}" == *"<"*">"* ]]; then
  echo ""
  echo -e "${RED}A URL do registry ainda contem um placeholder.${NC}"
  echo -e "${YELLOW}Defina ARTIFACTORY_NPM_BASEURL no devfile e rode novamente para fazer login.${NC}"
else
  echo ""
  if [ -n "${NPM_SCOPE}" ]; then
    echo -e "${YELLOW}Executando npm login com scope ${NPM_SCOPE}${NC}"
    npm login --registry "${ARTIFACTORY_NPM_BASEURL}" --scope "${NPM_SCOPE}"
  else
    echo -e "${YELLOW}Executando npm login${NC}"
    npm login --registry "${ARTIFACTORY_NPM_BASEURL}"
  fi
fi

# ================================
# FINAL
# ================================
echo ""
echo -e "${GREEN}Setup finalizado com sucesso ${NC}"
echo -e "${YELLOW}.npmrc gerado em:${NC} ${BLUE}${NPM_HOME_DIR}/.npmrc${NC}"

if [[ -d "${PERSISTENT_NPM_HOME}" && "${PERSISTENT_NPM_HOME}" != "${NPM_HOME_DIR}" ]]; then
  echo -e "${YELLOW}.npmrc gerado em:${NC} ${BLUE}${PERSISTENT_NPM_HOME}/.npmrc${NC}"
fi

if [[ -f "${NPM_HOME_DIR}/.npmrc.bak" ]]; then
  echo -e "${YELLOW}Backup criado em:${NC} ${BLUE}${NPM_HOME_DIR}/.npmrc.bak${NC}"
fi

if [[ -f "${PERSISTENT_NPM_HOME}/.npmrc.bak" && "${PERSISTENT_NPM_HOME}" != "${NPM_HOME_DIR}" ]]; then
  echo -e "${YELLOW}Backup criado em:${NC} ${BLUE}${PERSISTENT_NPM_HOME}/.npmrc.bak${NC}"
fi

echo ""
echo -e "${YELLOW}Valide com:${NC}"
echo -e "${BLUE}npm config get registry${NC}"
echo ""
echo -e "${YELLOW}Teste resolução de dependências com:${NC}"
echo -e "${BLUE}npm view express version${NC}"
echo ""
