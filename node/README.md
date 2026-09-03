# custom-udi-node

Imagem unica com tres versoes do Node. A troca e feita em runtime com `nodeuse`.

| Ferramenta | Versão |
| --- | --- |
| Node.js 22 | 22.23.1 |
| Node.js 24 | 24.18.0 (padrão) |
| Node.js 25 | 25.9.0 |
| npm | o empacotado em cada versão do Node |

| Comando | O que faz |
| --- | --- |
| `nodelist` | Lista as versões instaladas e marca a ativa |
| `nodeuse 22\|24\|25` | Troca a versão do shell atual e persiste a escolha |
| `node-versions [22\|24\|25]` | Sem argumento lista; com argumento troca |
| `devspaces-environment` | Mostra as versões ativas e instaladas |
| `devspaces-setup` | Configura o registry npm do Artifactory |

## Build

```
podman-compose -f image/compose.yaml --env-file image/.env build
```

## Test

```
podman run --rm --entrypoint /bin/bash quay.io/${QUAY_ORG}/${IMAGE_NAME}:${IMAGE_TAG} -lc '
  echo "== Node (padrao) =="; node -v; npm -v;
  echo "== nodelist =="; nodelist;
  echo "== nodeuse 22 =="; nodeuse 22; node -v;
  echo "== nodeuse 25 =="; nodeuse 25; node -v;
  echo "== volta para 22 =="; nodeuse 22; node -v;
  echo "== Environment =="; devspaces-environment;
'
```

## Push

```
podman login quay.io
podman-compose -f image/compose.yaml --env-file image/.env push
```
