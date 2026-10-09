# custom-udi-java

Imagem de workspace Java baseada na `custom-udi`, com **Java 8, 11, 17, 21 e 25** lado a lado
(default **25**), Maven, Gradle e Spring Boot CLI.

| Ferramenta | Versão | Local |
| --- | --- | --- |
| OpenJDK | 8 / 11 / 17 / 21 / 25 | `/usr/lib/jvm/java-{1.8.0,11,17,21,25}-openjdk` |
| Maven | 3.9.12 | `/opt/maven/current` |
| Gradle | 7.6.6 / 8.14.4 / 9.3.1 | `/opt/gradle/gradle-<versão>` |
| Spring Boot CLI | 2.7.18 / 4.0.3 | `/opt/spring-boot-cli/spring-<versão>` |

Os JDKs 8, 11, 17 e 21 vêm da imagem base; o 25 é instalado aqui.

## Troca de versão do Java

| Java | Gradle | Spring Boot CLI |
| --- | --- | --- |
| 8 | 7.6.6 | 2.7.18 |
| 11 | 7.6.6 | 2.7.18 |
| 17 | 8.14.4 | 4.0.3 |
| 21 | 8.14.4 | 4.0.3 |
| 25 (default) | 9.3.1 | 4.0.3 |

```bash
# Troca a versão ativa: ajusta JAVA_HOME, GRADLE_HOME e PATH e imprime java -version
use-java 8
use-java 11
use-java 17
use-java 21
use-java 25

# Executa um comando pontual em outra versão, sem mexer no shell
with-java 8 mvn -version
with-java 11 gradle build
```

**`use-java`** grava a escolha em `/home/user/persistent/.java-version`. Os terminais abertos
depois disso, inclusive após pause/resume do workspace, já iniciam na versão escolhida. Terminais
que já estavam abertos mantêm a versão deles. Sem o volume persistente, a troca vale só para o
shell corrente.

**`with-java`** não grava nada e não altera o shell: a versão vale só para o comando executado.

`use-java` é uma função definida em `/etc/profile.d/05-java-versions.sh`, disponível em shell de
login e no terminal interativo. Em `bash -c` não interativo (tasks, scripts) vale o default da
imagem; use `with-java` nesses casos.

O pareamento fica nos symlinks `/opt/gradle/java-<versão>` e `/opt/spring-boot-cli/java-<versão>`.
Não há `alternatives --set`: o workspace roda com UID arbitrário sob a SCC `restricted-v2` e isso
exigiria root.

> O editor não segue o `use-java`. A extensão Java detecta os cinco JDKs em `/usr/lib/jvm` e usa,
> em cada projeto, o que corresponde ao nível de compilação do `pom.xml` ou do `build.gradle`.

## Comandos

| Comando | O que faz |
| --- | --- |
| `use-java <versão>` | Troca a versão ativa do Java (com Gradle e Spring Boot CLI) e salva a escolha |
| `with-java <versão> <comando>` | Executa um comando em outra versão do Java |
| `devspaces-environment` | Mostra as versões das ferramentas e a conectividade com o repositório Maven |
| `devspaces-setup` | Gera o `settings.xml` do Maven com as credenciais do repositório |
| `devspaces-linux-release` | Mostra a versão da imagem base |

Variável lida pelos scripts (definida no devfile):

| Variável | Uso |
| --- | --- |
| `ARTIFACTORY_MAVEN_BASEURL` | Repositório Maven usado como mirror no `settings.xml` |

O `devspaces-setup` pede usuário e senha/token e grava `/home/user/persistent/.m2/settings.xml`
(modo 600, com backup `.bak`). Enquanto a URL for um placeholder `<...>`, ele aborta sem pedir
credenciais.

## Build

```
podman-compose -f image/compose.yaml --env-file image/.env build
```

O build executa `java`, `mvn`, `gradle` e `spring` em cada uma das cinco versões e falha se algum
par não funcionar.

## Test

```
podman run --rm --entrypoint /bin/bash quay.io/${QUAY_ORG}/${IMAGE_NAME}:${IMAGE_TAG} -lc '
  echo "== Default =="; java -version; mvn -version | head -n 3; gradle --version | grep "^Gradle"; spring --version;
  for v in 8 11 17 21 25; do
    echo "== Java $v =="; use-java $v;
    mvn -version | grep "Java version";
    gradle --version | grep -E "^Gradle|JVM";
    spring --version;
  done;
  use-java 25 > /dev/null 2>&1;
  echo "== with-java =="; with-java 8 java -version; java -version;
  echo "== Environment =="; devspaces-environment;
'
```

## Push

```
podman login quay.io
podman-compose -f image/compose.yaml --env-file image/.env push
```

---

## Notas de compatibilidade

**Gradle.** O 9.x exige Java 17+ para executar e é o primeiro a aceitar Java 25; o 8.14 não roda
em Java 25; o 7.6 cobre Java 8 e 11. Projetos com `./gradlew` usam a versão do próprio wrapper,
que precisa ser compatível com o JDK ativo.

**Spring Boot CLI.** O 4.x exige Java 17+. O 2.7.18 é a última versão para Java 8 e 11.

**OpenJDK 8 e 11 no RHEL 9.** O `java-11-openjdk` não recebe atualizações desde outubro/2024 e o
ciclo de vida do `java-1.8.0-openjdk` termina em **novembro/2026**. Planeje a migração dos
projetos legados.
