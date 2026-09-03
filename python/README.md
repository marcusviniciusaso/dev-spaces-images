# custom-udi-python

Imagem unica com quatro versoes do Python. A troca e feita em runtime com `pyuse`.

| Ferramenta | Versão | Origem |
| --- | --- | --- |
| Python 3.9 | 3.9.25 | gerenciador de pacotes |
| Python 3.12 | 3.12.14 (padrão) | gerenciador de pacotes |
| Python 3.13 | 3.13.15 | build do fonte |
| Python 3.14 | 3.14.7 | gerenciador de pacotes |
| pip | o empacotado em cada versão do Python | |

Cada versao vem do gerenciador de pacotes quando ha pacote disponivel na base; so cai para
build do fonte quando nao ha — hoje, apenas o 3.13 (o UBI 9.8 empacota o 3.14 e pula o 3.13).
As versoes fixadas para o build do fonte estao em `image/.env` e sao usadas so nesse caso.

| Comando | O que faz |
| --- | --- |
| `pylist` | Lista as versões instaladas e marca a ativa |
| `pyuse 3.9\|3.12\|3.13\|3.14` | Troca a versão do shell atual e persiste a escolha |
| `devspaces-environment` | Mostra as versões ativas e instaladas |
| `devspaces-setup` | Configura o índice PyPI do Artifactory |

`/usr/bin/python3` nao e alterado: `podman-compose`, `cekit` e `podman-mcp` da imagem base
continuam usando o interpretador do sistema. A versao selecionada e resolvida pelos wrappers
em `/opt/pyshims` (inicio do `PATH`) e, em shell de login, pelo bin real da versao.

## Build

```
podman-compose -f image/compose.yaml --env-file image/.env build
```

## Test

```
podman run --rm --entrypoint /bin/bash quay.io/${QUAY_ORG}/${IMAGE_NAME}:${IMAGE_TAG} -lc '
  echo "== Python (padrao) =="; python -V; pip -V;
  echo "== pylist =="; pylist;
  echo "== pyuse 3.9 =="; pyuse 3.9; python -V;
  echo "== pyuse 3.14 =="; pyuse 3.14; python -V;
  echo "== volta para 3.12 =="; pyuse 3.12; python -V;
  echo "== base intacta =="; /usr/bin/python3 -V; podman-compose --version;
  echo "== Environment =="; devspaces-environment;
'
```

## Push

```
podman login quay.io
podman-compose -f image/compose.yaml --env-file image/.env push
```
