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
    command -v use-java > /dev/null 2>&1 || . /etc/profile.d/05-java-versions.sh
    for v in 8 11 17 21 25; do
        echo "-- Java $v --"
        use-java "$v" || echo "não disponível"
    done
    use-java 21 > /dev/null 2>&1
}

get_maven_version() {
    mvn -version | head -n 5
}

get_chrome_version() {
    chrome --version || echo "não disponível"
}

get_chromedriver_version() {
    chromedriver --version || echo "não disponível"
}

get_jmeter_version() {
    JMETER_SHOW_JVM=true jmeter -v 2>&1 | grep -v StatusConsoleListener | head -n 10
}

echo ""
echo "=============================================================================="
echo " DevSpaces Java Environment"
echo "=============================================================================="
echo ""

print_line "Java" "$(get_java_version)"
print_line "Maven" "$(get_maven_version)"
print_line "Chrome" "$(get_chrome_version)"
print_line "Chromedriver" "$(get_chromedriver_version)"
print_line "JMeter" "$(get_jmeter_version)"
