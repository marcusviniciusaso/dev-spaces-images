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
    local code

    if [[ -z "${url}" || "${url}" == *"<"*">"* ]]; then
        printf "${YELLOW}•${NC} %-20s não configurado\n" "${name}"
        return 0
    fi

    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "${url}" || true)"
    if [[ "${code}" =~ ^[1-4][0-9][0-9]$ ]]; then
        printf "${GREEN}✔${NC} %-20s %s (HTTP %s)\n" "${name}" "${url}" "${code}"
    else
        printf "${RED}✘${NC} %-20s %s (HTTP %s)\n" "${name}" "${url}" "${code:-000}"
    fi
}

get_java_version() {
    java -version 2>&1 | head -n 1 | sed 's/"//g'
}

get_installed_jdks() {
    local v home version

    for v in 8 11 17 21 25; do
        home="$(_java_home_for "$v")"
        [[ -x "${home}/bin/java" ]] || continue
        version="$("${home}/bin/java" -version 2>&1 | awk -F'"' 'NR == 1 {print $2}')"
        printf '%s (%s)\n' "$v" "${version}"
    done | paste -sd',' - | sed 's/,/, /g'
}

get_saved_version() {
    local version

    version="$(_java_saved_version)"
    if [[ -n "${version}" ]]; then
        printf '%s (/home/user/persistent/.java-version)\n' "${version}"
    else
        printf '%s (padrão da imagem)\n' "${JAVA_DEFAULT_VERSION:-}"
    fi
}

get_maven_version() {
    mvn -version 2>/dev/null | head -n 1
}

get_gradle_version() {
    gradle --version 2>/dev/null | grep "^Gradle" | head -n 1
}

get_spring_boot_version() {
    if command -v spring >/dev/null 2>&1; then
        spring --version 2>/dev/null
    fi
}

JDKS="$(. /etc/profile.d/05-java-versions.sh; get_installed_jdks)"
SAVED="$(. /etc/profile.d/05-java-versions.sh; get_saved_version)"

echo ""
echo "=============================================================================="
echo " DevSpaces Java Environment"
echo "=============================================================================="
echo ""

print_line "Java" "$(get_java_version)"
print_line "JAVA_HOME" "${JAVA_HOME:-}"
print_line "JDKs instalados" "${JDKS}"
print_line "Novos terminais" "${SAVED}"
print_line "Maven" "$(get_maven_version)"
print_line "Gradle" "$(get_gradle_version)"
print_line "Spring Boot" "$(get_spring_boot_version)"

echo ""
echo "=============================================================================="
echo " Conectividade"
echo "=============================================================================="
echo ""

print_url "Repo Maven" "${ARTIFACTORY_MAVEN_BASEURL:-}"

echo ""
echo "=============================================================================="
echo -e "${YELLOW}Troca de versão do Java:${NC}"
echo "=============================================================================="
echo ""
echo "  use-java 8|11|17|21|25              # troca a versão ativa (fica salva)"
echo "  with-java 8|11|17|21|25 <comando>   # troca só para o comando"

echo ""
echo "=============================================================================="
echo -e "${YELLOW}IMPORTANTE: Se esta é a primeira vez, configure as credenciais:${NC}"
echo "=============================================================================="
echo ""
echo -e "${BLUE}Execute:${NC}"
echo "  devspaces-setup"
echo ""
echo -e "${YELLOW}Isso irá:${NC}"
echo "  • Solicitar usuário e senha do Artifactory"
echo "  • Configurar settings.xml com credenciais"
echo "  • Salvar configuração em persistent storage"
echo ""
