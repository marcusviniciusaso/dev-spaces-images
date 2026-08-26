#!/usr/bin/env bash
# Wrapper instalado como /usr/local/bin/jmeter.
#
# O Groovy 3.0.x embarcado no JMeter 5.6.3 quebra em JDK 22+ (apache/jmeter#6114,
# apache/jmeter#6402) e ha incompatibilidade reportada com Java 25 (apache/jmeter#6611).
# Por isso o JMeter roda SEMPRE no JDK 21, independentemente do "use-java" ativo
# no shell. /opt/jmeter/current/bin fica fora do PATH justamente para que este
# wrapper seja o unico "jmeter" alcancavel.
#
# Override consciente: JMETER_JAVA_HOME=/usr/lib/jvm/java-17-openjdk jmeter ...
# Heap:               HEAP="-Xms512m -Xmx2g" jmeter ...
# Diagnostico:        JMETER_SHOW_JVM=true jmeter -v

export JAVA_HOME="${JMETER_JAVA_HOME:-/usr/lib/jvm/java-21-openjdk}"
export PATH="${JAVA_HOME}/bin:${PATH}"

# Heap conservador: o pod tem memoryLimit finito. Sobrescrevivel via env HEAP.
export HEAP="${HEAP:--Xms256m -Xmx1g}"

if [ "${JMETER_SHOW_JVM:-}" = "true" ]; then
    echo "[jmeter] JAVA_HOME=${JAVA_HOME}" >&2
    "${JAVA_HOME}/bin/java" -version >&2
fi

exec /opt/jmeter/current/bin/jmeter "$@"
