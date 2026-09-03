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
ARTIFACTORY_PYPI_BASEURL="${ARTIFACTORY_PYPI_BASEURL:-https://<ARTIFACTORY_URL>/artifactory/public-pypi-central}"

# ================================
# DESTINOS DO PIP.CONF
# ================================
if [ -d /home/user/persistent ] && [ -w /home/user/persistent ]; then
  PIP_HOME_DIR="${PIP_HOME_DIR:-/home/user/persistent}"
else
  PIP_HOME_DIR="${PIP_HOME_DIR:-/home/user}"
fi
PERSISTENT_PIP_HOME="${PERSISTENT_PIP_HOME:-/home/user/persistent}"

# ================================
# GUARDA DE PLACEHOLDER
# ================================
if [[ "${ARTIFACTORY_PYPI_BASEURL}" == *"<"*">"* ]]; then
  echo ""
  echo -e "${RED}A URL do índice PyPI ainda contem um placeholder:${NC}"
  echo -e "${BLUE}${ARTIFACTORY_PYPI_BASEURL}${NC}"
  echo ""
  echo -e "${YELLOW}Defina ARTIFACTORY_PYPI_BASEURL no devfile e rode novamente.${NC}"
  echo -e "${YELLOW}Nenhuma credencial foi solicitada ou gravada.${NC}"
  exit 1
fi

# ================================
# HELPERS
# ================================
# As credenciais vao embutidas no index-url, entao precisam ser percent-encoded:
# uma senha com @ : / # ? quebraria a URL.
url_encode() {
  local value="$1"
  local i char out=""

  for (( i = 0; i < ${#value}; i++ )); do
    char="${value:i:1}"
    case "$char" in
      [A-Za-z0-9.~_-]) out+="$char" ;;
      *) out+="$(printf '%%%02X' "'$char")" ;;
    esac
  done

  printf '%s' "$out"
}

# ================================
# INPUT USER / PASSWORD
# ================================
read -r -p "Informe o usuário do Artifactory: " PYPI_USERNAME
[[ -z "${PYPI_USERNAME}" ]] && { echo -e "${RED}Usuário obrigatório${NC}"; exit 1; }

read -r -s -p "Informe a senha/token do Artifactory: " PYPI_PASSWORD
[[ -z "${PYPI_PASSWORD}" ]] && { echo -e "${RED}Senha obrigatória${NC}"; exit 1; }
echo ""

PYPI_USERNAME_ENC="$(url_encode "$PYPI_USERNAME")"
PYPI_PASSWORD_ENC="$(url_encode "$PYPI_PASSWORD")"

# ================================
# MONTA URL
# ================================
PYPI_HOST_PATH="$(printf '%s' "${ARTIFACTORY_PYPI_BASEURL}" | sed -E 's|^https?://||; s|/+$||')"
PYPI_TRUSTED_HOST="$(printf '%s' "${PYPI_HOST_PATH}" | cut -d/ -f1 | cut -d: -f1)"
PYPI_INDEX_URL="https://${PYPI_USERNAME_ENC}:${PYPI_PASSWORD_ENC}@${PYPI_HOST_PATH}/simple"

# ================================
# ESCREVE PIP.CONF
# ================================
write_pip_config() {
  local target_file="$1"
  local target_dir
  local tmp_file

  target_dir="$(dirname "${target_file}")"
  mkdir -p "${target_dir}"

  if [[ -f "${target_file}" ]]; then
    cp "${target_file}" "${target_file}.bak"
    chmod 600 "${target_file}.bak" 2>/dev/null || true
  fi

  tmp_file="$(mktemp "${target_dir}/pip.conf.tmp.XXXXXX")"
  chmod 600 "${tmp_file}"

  cat > "${tmp_file}" <<EOF
[global]
index-url = ${PYPI_INDEX_URL}
trusted-host = ${PYPI_TRUSTED_HOST}
timeout = 60
disable-pip-version-check = true

[install]
no-cache-dir = false
EOF

  mv -f "${tmp_file}" "${target_file}"
  chmod 600 "${target_file}"
}

# O .bashrc e o devfile exportam PIP_CONFIG_FILE; quando definido, ele e o
# caminho que o pip realmente le e tem prioridade.
PIP_CONFIG_TARGETS=()

if [[ -n "${PIP_CONFIG_FILE:-}" ]]; then
  PIP_CONFIG_TARGETS+=("${PIP_CONFIG_FILE}")
fi

PIP_CONFIG_TARGETS+=("${PIP_HOME_DIR}/.pip/pip.conf")

if [[ -d "${PERSISTENT_PIP_HOME}" && "${PERSISTENT_PIP_HOME}" != "${PIP_HOME_DIR}" ]]; then
  PIP_CONFIG_TARGETS+=("${PERSISTENT_PIP_HOME}/.pip/pip.conf")
fi

WRITTEN_TARGETS=()

for target in "${PIP_CONFIG_TARGETS[@]}"; do
  already=0
  for written in ${WRITTEN_TARGETS[@]+"${WRITTEN_TARGETS[@]}"}; do
    [[ "$written" == "$target" ]] && already=1 && break
  done
  [[ "$already" -eq 1 ]] && continue

  write_pip_config "$target"
  WRITTEN_TARGETS+=("$target")
done

# ================================
# FINAL
# ================================
echo ""
echo -e "${GREEN}Setup finalizado com sucesso ${NC}"
echo -e "${YELLOW}Índice configurado:${NC} ${BLUE}https://${PYPI_HOST_PATH}/simple${NC}"

for written in "${WRITTEN_TARGETS[@]}"; do
  echo -e "${YELLOW}pip.conf gerado em:${NC} ${BLUE}${written}${NC}"
  if [[ -f "${written}.bak" ]]; then
    echo -e "${YELLOW}Backup criado em:${NC} ${BLUE}${written}.bak${NC}"
  fi
done

echo ""
echo -e "${YELLOW}Valide com:${NC}"
echo -e "${BLUE}pip config list${NC}"
echo ""
echo -e "${YELLOW}Teste resolução de dependências com:${NC}"
echo -e "${BLUE}pip download --no-deps requests -d /tmp/pip-test${NC}"
