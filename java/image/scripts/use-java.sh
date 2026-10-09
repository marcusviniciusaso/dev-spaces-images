_java_home_for() {
    case "$1" in
        8)  echo "/usr/lib/jvm/java-1.8.0-openjdk" ;;
        11) echo "/usr/lib/jvm/java-11-openjdk" ;;
        17) echo "/usr/lib/jvm/java-17-openjdk" ;;
        21) echo "/usr/lib/jvm/java-21-openjdk" ;;
        25) echo "/usr/lib/jvm/java-25-openjdk" ;;
        *)  return 1 ;;
    esac
}

_java_env_apply() {
    local version="${1:-}" java_home entry path=""
    local -a entries

    java_home="$(_java_home_for "$version")" || return 1
    [ -x "${java_home}/bin/java" ] || return 2

    IFS=':' read -ra entries <<< "$PATH"
    for entry in "${entries[@]}"; do
        case "$entry" in
            /usr/lib/jvm/*|/opt/gradle/*|/opt/spring-boot-cli/*) ;;
            *) path="${path:+${path}:}${entry}" ;;
        esac
    done

    export JAVA_HOME="${java_home}"
    export GRADLE_HOME="/opt/gradle/java-${version}"
    export PATH="${JAVA_HOME}/bin:${GRADLE_HOME}/bin:/opt/spring-boot-cli/java-${version}/bin:${path}"
}

_java_saved_version() {
    local version=""

    if [ -r /home/user/persistent/.java-version ]; then
        read -r version < /home/user/persistent/.java-version || true
    fi
    printf '%s' "${version//[[:space:]]/}"
}

use-java() {
    local version="${1:-}"

    _java_env_apply "$version" || {
        if [ $? -eq 2 ]; then
            echo "use-java: JDK ${version} nao encontrado em $(_java_home_for "$version")" >&2
        else
            echo "uso: use-java 8|11|17|21|25" >&2
        fi
        return 1
    }

    if [ -d /home/user/persistent ] && [ -w /home/user/persistent ]; then
        printf '%s\n' "$version" > /home/user/persistent/.java-version
    fi

    java -version
}

_java_env_apply "${DEVSPACES_JAVA_VERSION:-}" \
    || _java_env_apply "$(_java_saved_version)" \
    || _java_env_apply "${JAVA_DEFAULT_VERSION:-25}" \
    || true
