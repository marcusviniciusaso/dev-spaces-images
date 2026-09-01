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

get_java_version() {
    java -version 2>&1 | head -n 1 | sed 's/"//g'
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

echo ""
echo "=============================================================================="
echo " DevSpaces Java 17 Environment"
echo "=============================================================================="
echo ""

print_line "Java" "$(get_java_version)"
print_line "Maven" "$(get_maven_version)"
print_line "Gradle" "$(get_gradle_version)"
print_line "Spring Boot" "$(get_spring_boot_version)"

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
