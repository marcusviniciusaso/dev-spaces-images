# Troca o JDK do shell corrente: use-java 8|11|17|21|25
# Nao usa "alternatives --set" de proposito: exigiria root, e o workspace roda
# com UID arbitrario sob a SCC restricted-v2.
# Para um comando pontual em outro JDK sem trocar o shell, use "with-java".

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

use-java() {
    local version="${1:-}" java_home

    java_home="$(_java_home_for "$version")" || {
        echo "uso: use-java 8|11|17|21|25" >&2
        return 1
    }

    if [ ! -x "${java_home}/bin/java" ]; then
        echo "use-java: JDK ${version} nao encontrado em ${java_home}" >&2
        return 1
    fi

    # Remove qualquer JDK previamente prefixado no PATH antes de adicionar o novo
    PATH="$(printf '%s' "$PATH" | tr ':' '\n' | grep -v '^/usr/lib/jvm/' | paste -sd: -)"

    export JAVA_HOME="${java_home}"
    export PATH="${java_home}/bin:${PATH}"

    java -version
}
