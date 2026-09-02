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
ARTIFACTORY_MAVEN_BASEURL="${ARTIFACTORY_MAVEN_BASEURL:-https://<ARTIFACTORY_URL>/artifactory/public-maven-central/}"

# ================================
# HELPERS
# ================================
xml_escape() {
  local value="$1"
  value="${value//&/&amp;}"
  value="${value//</&lt;}"
  value="${value//>/&gt;}"
  value="${value//\"/&quot;}"
  value="${value//\'/&apos;}"
  printf '%s' "$value"
}

repo_id_for_url() {
  local url="$1"
  echo "repo-$(printf '%s' "$url" | md5sum | cut -c1-8)"
}

# ================================
# INPUT USER / PASSWORD
# ================================
read -r -p "Informe o usuário do Maven: " MAVEN_USERNAME
[[ -z "${MAVEN_USERNAME}" ]] && { echo -e "${RED}Usuário obrigatório${NC}"; exit 1; }

read -r -s -p "Informe a senha/token do Maven: " MAVEN_PASSWORD
[[ -z "${MAVEN_PASSWORD}" ]] && { echo -e "${RED}Senha obrigatória${NC}"; exit 1; }
echo ""

MAVEN_USERNAME_XML="$(xml_escape "$MAVEN_USERNAME")"
MAVEN_PASSWORD_XML="$(xml_escape "$MAVEN_PASSWORD")"
ARTIFACTORY_MAVEN_BASEURL_XML="$(xml_escape "$ARTIFACTORY_MAVEN_BASEURL")"

# ================================
# INPUT REPOS
# ================================
echo "Repositórios Maven adicionais (Artifactory), separados por vírgula
(ou ENTER para nenhum repositório adicional)"
echo "Exemplo: https://repo1,https://repo2"
read -r -p "Repos: " MAVEN_REPOS

REPO_LIST=()

if [[ -n "${MAVEN_REPOS}" ]]; then
  IFS=',' read -ra RAW_REPO_LIST <<< "$MAVEN_REPOS"

  for repo in "${RAW_REPO_LIST[@]}"; do
    repo_trimmed="$(echo "$repo" | xargs)"

    [[ -z "$repo_trimmed" ]] && continue

    if [[ "$repo_trimmed" != http://* && "$repo_trimmed" != https://* ]]; then
      echo -e "${RED}Repo inválido: $repo_trimmed${NC}"
      exit 1
    fi

    REPO_LIST+=("$repo_trimmed")
  done
fi

# ================================
# MONTA XML
# ================================
SERVERS_XML=""
REPOSITORIES_XML=""
PLUGIN_REPOSITORIES_XML=""
MIRROR_EXCLUSIONS=""

SERVERS_XML="${SERVERS_XML}
    <server>
      <id>artifactory-mirror</id>
      <username>${MAVEN_USERNAME_XML}</username>
      <password>${MAVEN_PASSWORD_XML}</password>
    </server>"

for repo in "${REPO_LIST[@]}"; do
  repo_id="$(repo_id_for_url "$repo")"
  repo_xml="$(xml_escape "$repo")"

  MIRROR_EXCLUSIONS="${MIRROR_EXCLUSIONS},!${repo_id}"

  SERVERS_XML="${SERVERS_XML}
    <server>
      <id>${repo_id}</id>
      <username>${MAVEN_USERNAME_XML}</username>
      <password>${MAVEN_PASSWORD_XML}</password>
    </server>"

  REPOSITORIES_XML="${REPOSITORIES_XML}
        <repository>
          <id>${repo_id}</id>
          <url>${repo_xml}</url>
          <releases>
            <enabled>true</enabled>
          </releases>
          <snapshots>
            <enabled>true</enabled>
          </snapshots>
        </repository>"

  PLUGIN_REPOSITORIES_XML="${PLUGIN_REPOSITORIES_XML}
        <pluginRepository>
          <id>${repo_id}</id>
          <url>${repo_xml}</url>
          <releases>
            <enabled>true</enabled>
          </releases>
          <snapshots>
            <enabled>true</enabled>
          </snapshots>
        </pluginRepository>"
done

MIRROR_OF="*,!artifactory-mirror${MIRROR_EXCLUSIONS}"

# ================================
# ESCREVE SETTINGS
# ================================
if [ -d /home/user/persistent ] && [ -w /home/user/persistent ]; then
  MAVEN_HOME_DIR="${MAVEN_HOME_DIR:-/home/user/persistent}"
else
  MAVEN_HOME_DIR="${MAVEN_HOME_DIR:-/home/user}"
fi
PERSISTENT_MAVEN_HOME="${PERSISTENT_MAVEN_HOME:-/home/user/persistent}"

write_settings_file() {
  local target_home="$1"
  local target_dir="${target_home}/.m2"
  local target_file="${target_dir}/settings.xml"
  local tmp_file

  mkdir -p "${target_dir}"

  if [[ -f "${target_file}" ]]; then
    cp "${target_file}" "${target_file}.bak"
  fi

  tmp_file="$(mktemp "${target_dir}/settings.xml.tmp.XXXXXX")"

  cat > "${tmp_file}" <<EOF
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                              https://maven.apache.org/xsd/settings-1.0.0.xsd">

  <servers>${SERVERS_XML}
  </servers>

  <mirrors>
    <mirror>
      <id>artifactory-mirror</id>
      <mirrorOf>${MIRROR_OF}</mirrorOf>
      <url>${ARTIFACTORY_MAVEN_BASEURL_XML}</url>
    </mirror>
  </mirrors>

  <profiles>
    <profile>
      <id>default</id>

      <repositories>
        <repository>
          <id>artifactory-default</id>
          <url>${ARTIFACTORY_MAVEN_BASEURL_XML}</url>
          <releases>
            <enabled>true</enabled>
          </releases>
          <snapshots>
            <enabled>true</enabled>
          </snapshots>
        </repository>${REPOSITORIES_XML}
      </repositories>

      <pluginRepositories>
        <pluginRepository>
          <id>artifactory-default</id>
          <url>${ARTIFACTORY_MAVEN_BASEURL_XML}</url>
          <releases>
            <enabled>true</enabled>
          </releases>
          <snapshots>
            <enabled>true</enabled>
          </snapshots>
        </pluginRepository>${PLUGIN_REPOSITORIES_XML}
      </pluginRepositories>

    </profile>
  </profiles>

  <activeProfiles>
    <activeProfile>default</activeProfile>
  </activeProfiles>

</settings>
EOF

  mv -f "${tmp_file}" "${target_file}"
}

write_settings_file "${MAVEN_HOME_DIR}"

if [[ -d "${PERSISTENT_MAVEN_HOME}" && "${PERSISTENT_MAVEN_HOME}" != "${MAVEN_HOME_DIR}" ]]; then
  write_settings_file "${PERSISTENT_MAVEN_HOME}"
fi

# ================================
# FINAL
# ================================
echo ""
echo -e "${GREEN}Setup finalizado com sucesso ${NC}"
echo -e "${YELLOW}settings.xml gerado em:${NC} ${BLUE}${MAVEN_HOME_DIR}/.m2/settings.xml${NC}"

if [[ -d "${PERSISTENT_MAVEN_HOME}" && "${PERSISTENT_MAVEN_HOME}" != "${MAVEN_HOME_DIR}" ]]; then
  echo -e "${YELLOW}settings.xml gerado em:${NC} ${BLUE}${PERSISTENT_MAVEN_HOME}/.m2/settings.xml${NC}"
fi

if [[ -f "${MAVEN_HOME_DIR}/.m2/settings.xml.bak" ]]; then
  echo -e "${YELLOW}Backup criado em:${NC} ${BLUE}${MAVEN_HOME_DIR}/.m2/settings.xml.bak${NC}"
fi

if [[ -f "${PERSISTENT_MAVEN_HOME}/.m2/settings.xml.bak" && "${PERSISTENT_MAVEN_HOME}" != "${MAVEN_HOME_DIR}" ]]; then
  echo -e "${YELLOW}Backup criado em:${NC} ${BLUE}${PERSISTENT_MAVEN_HOME}/.m2/settings.xml.bak${NC}"
fi

echo ""
echo -e "${YELLOW}Valide com:${NC}"
echo -e "${BLUE}cat ${MAVEN_HOME_DIR}/.m2/settings.xml${NC}"
echo ""
echo -e "${YELLOW}Teste resolução de dependências com:${NC}"
echo -e "${BLUE}mvn -U dependency:resolve${NC}"
