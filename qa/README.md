# custom-udi-qa

Imagem de workspace para a equipe de QA: **Java 8, 11, 17, 21 e 25** lado a lado (default **21**),
**Maven**, **Selenium** (Chrome for Testing + chromedriver pareados) e **Apache JMeter**.

| Ferramenta | Versão | Local |
| --- | --- | --- |
| OpenJDK | 8 / 11 / 17 / 21 / 25 | `/usr/lib/jvm/java-{1.8.0,11,17,21,25}-openjdk` |
| Maven | 3.9.12 | `/opt/maven/current` |
| Chrome for Testing | 152.0.7977.64 | `/opt/chrome/current`, binário em `/usr/local/bin/chrome` |
| chromedriver | 152.0.7977.64 | `/usr/local/bin/chromedriver` |
| Apache JMeter | 5.6.3 | `/opt/jmeter/current`, wrapper em `/usr/local/bin/jmeter` |

## Troca de versão do Java

O JDK default é o **21** (`JAVA_HOME=/usr/lib/jvm/java-21-openjdk`). Não há `alternatives --set`:
o workspace roda com UID arbitrário sob a SCC `restricted-v2` e isso exigiria root.

```bash
# Troca o JDK do shell corrente (imprime java -version ao final)
use-java 8
use-java 11
use-java 17
use-java 21
use-java 25

# Executa um comando pontual em outro JDK, sem mexer no shell
with-java 8 mvn -version
with-java 11 mvn test
```

`use-java` é uma função definida em `/etc/profile.d/05-java-versions.sh` — disponível em shell de
login e no terminal interativo. Em `bash -c` não-interativo (tasks de devfile, scripts) use `with-java`.

> **Projetos legados**: Maven 3.9 roda em Java 8+, então funciona com qualquer JDK ativo. Para compilar
> um projeto legado, use `use-java 8` / `use-java 11` antes do build, ou mantenha o JVM default e
> configure `maven-toolchains-plugin` / `<release>` no `pom.xml`.

## JMeter

`/usr/local/bin/jmeter` é um **wrapper que força o JDK 21**, independentemente do `use-java` ativo
(ver *Notas de compatibilidade*). `/opt/jmeter/current/bin` fica fora do `PATH` de propósito, para
que o wrapper seja o único `jmeter` alcançável.

```bash
jmeter -n -t plano.jmx -l /tmp/resultado.jtl -j /tmp/jmeter.log        # execução non-GUI
jmeter -n -t plano.jmx -l /tmp/resultado.jtl -e -o /tmp/jmeter-report  # + relatório HTML

HEAP="-Xms512m -Xmx2g" jmeter -n -t plano.jmx -l /tmp/resultado.jtl    # heap (default -Xms256m -Xmx1g)
JMETER_SHOW_JVM=true jmeter -v                                        # mostra qual JVM está em uso
```

Um plano mínimo de smoke test acompanha a imagem em `/opt/jmeter/examples/smoke-plan.jmx`
(HTTP GET em `http://localhost:8000/index.html`, servido pelo `jwebserver` do próprio JDK — zero egress).

## Build image

```
podman-compose -f image/compose.yaml --env-file image/.env build
```

## Test

> `--entrypoint /bin/bash` é necessário: o entrypoint da UDI usa `set -e` e aborta fora do OpenShift,
> ao tentar criar symlinks em `/home/user/.config` sem as permissões que o cluster fornece.
>
> Em **Mac Apple Silicon** a imagem `linux/amd64` roda sob emulação QEMU e o smoke headless do Chrome
> morre com `qemu: uncaught target signal 5` — limitação do emulador, não da imagem. `chrome --version`,
> `chromedriver --version` e o `ldd` continuam válidos; valide o headless no workspace (task
> `validate-browser`) ou numa máquina x86_64, onde ele passa normalmente.

```bash
podman run --rm --entrypoint /bin/bash quay.io/${QUAY_ORG}/${IMAGE_NAME}:${IMAGE_TAG} -lc '
  echo "== JDKs (use-java) ==";
  for v in 8 11 17 21 25; do echo "-- Java $v --"; use-java $v; done;
  use-java 21 > /dev/null 2>&1;

  echo "== Java default =="; bash -lc "java -version";
  echo "== Maven =="; mvn -version | head -n 5;

  echo "== Chrome =="; chrome --version;
  echo "== Chromedriver =="; chromedriver --version;
  echo "== Library check (must be empty) ==";
  ldd /opt/chrome/current/chrome | grep "not found" || echo "OK: all libs resolved";
  echo "== Headless smoke test ==";
  chrome --headless=new --no-sandbox --disable-dev-shm-usage --disable-gpu --dump-dom about:blank 2>/dev/null | head -1;

  echo "== JMeter com Java 25 ativo no shell (deve reportar JVM 21) ==";
  use-java 25 > /dev/null 2>&1;
  JMETER_SHOW_JVM=true jmeter -v 2>&1 | grep -v StatusConsoleListener | head -n 10;

  echo "== JMeter smoke non-GUI ==";
  with-java 21 jwebserver -p 8000 -b 127.0.0.1 -d /opt/jmeter/examples > /tmp/jwebserver.log 2>&1 &
  WEB_PID=$!;
  sleep 5;
  kill -0 $WEB_PID 2>/dev/null || { echo "ERRO: jwebserver nao subiu (porta 8000 ocupada?)"; cat /tmp/jwebserver.log; };
  rm -f /tmp/result.jtl;
  jmeter -n -t /opt/jmeter/examples/smoke-plan.jmx -l /tmp/result.jtl -j /tmp/jmeter.log;
  kill $WEB_PID 2>/dev/null;
  echo "-- resultado --"; cat /tmp/result.jtl;
'
```

### Ruído esperado do Chrome headless

O Chrome despeja no **stderr** dezenas de linhas `ERROR:` que **não são falha**. Por isso todas as
invocações do Chrome neste projeto usam `2>/dev/null`. As mensagens mais comuns:

| Mensagem | Causa | Impacto |
| --- | --- | --- |
| `Failed to connect to the bus: Address does not contain a colon` | `DBUS_SESSION_BUS_ADDRESS=/dev/null` não é um endereço D-Bus válido (falta o `transport:`) — é o hack convencional para container | nenhum |
| `Failed to connect to socket /run/dbus/system_bus_socket` | barramento de **sistema**; não existe daemon D-Bus no pod | nenhum |
| `xcb_connect() failed` / `ANGLE Display::initialize error` / `eglInitialize SwANGLE failed` | mesmo com `--disable-gpu` o Chrome sobe um processo de GPU, que falha ao inicializar ANGLE/EGL sem X11 | nenhum |
| `Exiting GPU process due to errors during initialization` | consequência da linha acima; a renderização cai para software | nenhum |

**O critério de sucesso é a linha `<html><head></head><body></body></html>`**, não a ausência de
`ERROR:` no stderr.

Quando o smoke **não** imprimir o `<html>`, aí sim rode de novo **sem** o `2>/dev/null` e leia o
stderr. O que interessa nesse caso é outro tipo de mensagem:

- erro de shared library → cruzar com `ldd /opt/chrome/current/chrome | grep "not found"`
- `Failed to create headless user data directory container` → `$HOME` sem escrita; passar `--user-data-dir=/tmp/chrome-profile`
- crash imediato → `/dev/shm` pequeno; confirmar `--disable-dev-shm-usage`

O mesmo ruído aparece no log do chromedriver durante `mvn test` — não afeta o resultado dos testes.

**Por que não tentamos silenciar na origem** (medido no cluster, Chrome 152.0.7977.64):

| Tentativa | Linhas `ERROR:` | Veredito |
| --- | --- | --- |
| baseline | 63 | — |
| `env -u DBUS_SESSION_BUS_ADDRESS` | 63 | sem efeito: sem a env o Chrome só troca a mensagem (passa a falhar no autolaunch do barramento de sistema). O valor `/dev/null` não é a causa, e nenhum outro valor resolve — o que falta é o daemon D-Bus, que não existe no pod |
| `--log-level=3` | 0, mas **restam 12 linhas `ERR:`** do ANGLE | não é silêncio completo, e esconderia erro real do browser dentro do `mvn test` |

Por isso a imagem mantém `DBUS_SESSION_BUS_ADDRESS=/dev/null` e o logging default do Chrome: o
filtro fica no comando (`2>/dev/null`), onde basta removê-lo para ver tudo quando algo quebra.

## Push to Quay

```
podman login quay.io

podman-compose -f image/compose.yaml --env-file image/.env push
```

---

## Notas de compatibilidade

**Selenium 4.x exige JVM 11+** (desde a 4.14; a proposta de subir para Java 17 foi descartada —
[SeleniumHQ/selenium#14022](https://github.com/SeleniumHQ/selenium/issues/14022)). Projetos de teste
não rodam Selenium 4 em JVM 8. Orientação: compile a **aplicação** para 8 (`--release 8`), mas
**execute os testes** em JVM 11+ (ideal: 21). O Selenium 3.141.59 (última com suporte a Java 8) está
EOL desde 2021 e não deve ser usado com o Chrome atual.

**JMeter 5.6.3 roda em Java 8+, recomendado 17+, e quebra com Groovy em JDK 22+**
([apache/jmeter#6114](https://github.com/apache/jmeter/issues/6114),
[#6402](https://github.com/apache/jmeter/issues/6402)), com incompatibilidade também reportada em
Java 25 ([#6611](https://github.com/apache/jmeter/issues/6611)). Por isso o `jmeter` exposto é um
wrapper pinado no JDK 21 — sem ele, herdaria o Java 25 quando ativo e falharia. A próxima major do
JMeter exigirá Java 17+.

**A GUI do JMeter não existe no workspace** (container headless). A autoria de planos é feita em
modo non-GUI / edição do XML, na máquina local do QA, ou — último recurso — via VNC/noVNC. **Carga
real não deve ser gerada de dentro do workspace**: os limites de CPU/memória do pod distorcem os
resultados. O workspace serve para desenvolver, versionar e rodar smoke tests dos planos.

**Plugins Manager não é instalado**: ele baixaria jars em runtime. Se algum plugin for necessário,
embuta o jar pinado na imagem.

**Chrome/chromedriver independem do Java** — as cinco versões de JDK não impõem restrição alguma
ao browser. Chrome e chromedriver são sempre um **par casado** (mesma versão exata).

**Selenium Manager (4.6+) baixa o driver da internet** se não encontrar um. Mantenha
`webdriver.chrome.driver` (ou a env `WEBDRIVER_CHROME_DRIVER`) apontando para o chromedriver da
imagem, para funcionar sem egress.

**OpenJDK 8 no RHEL 9**: o ciclo de vida do `java-1.8.0-openjdk` da Red Hat termina em
**novembro/2026**. Planeje a migração dos projetos legados.
