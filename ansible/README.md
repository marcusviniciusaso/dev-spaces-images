# custom-udi-ansible

Imagem de workspace Ansible baseada na `custom-udi`, para criar, validar e executar playbooks.

| Ferramenta | Versão | Origem |
| --- | --- | --- |
| ansible-dev-tools | 26.9.0 | pip (venv `/opt/ansible`) |
| ansible-core | 2.21.4 | pip (venv `/opt/ansible`) |
| ansible-lint | incluída no ADT | pip (venv `/opt/ansible`) |
| ansible-navigator | incluída no ADT | pip (venv `/opt/ansible`) |
| ansible-builder | incluída no ADT | pip (venv `/opt/ansible`) |
| molecule / ansible-creator | incluídas no ADT | pip (venv `/opt/ansible`) |
| Python 3.12 | o do gerenciador de pacotes | interpretador do venv |

As ferramentas ficam num venv isolado com Python 3.12 (o ansible-core 2.21 exige Python >= 3.12).
Os entrypoints (`ansible*`, `molecule`, `ade`, ...) são expostos em `/usr/local/bin`, e o venv entra
só no **fim** do `PATH` (o ansible-lint exige isso), então `/usr/bin/python3`, `podman-compose` e `cekit` da imagem base continuam
usando o interpretador do sistema.

Nenhuma collection vem embutida: o desenvolvedor instala as collections a partir do Automation Hub
(`devspaces-setup` + `ansible-galaxy collection install`), em `$ANSIBLE_HOME/collections`, que fica
em persistent storage.

| Comando | O que faz |
| --- | --- |
| `devspaces-environment` | Mostra as versões das ferramentas e a conectividade com AAP e Automation Hub |
| `devspaces-setup` | Configura o servidor Galaxy (Automation Hub), faz login no registry de EEs e verifica o AAP |
| `devspaces-linux-release` | Mostra a versão da imagem base |

Variáveis lidas pelos scripts (definidas no devfile):

| Variável | Uso |
| --- | --- |
| `AUTOMATION_HUB_URL` | URL do Automation Hub (raiz ou URL completa da API Galaxy) |
| `AUTOMATION_HUB_AUTH_URL` | Opcional; URL do SSO quando o Hub exige (vazio para Private Automation Hub) |
| `AUTOMATION_HUB_REGISTRY` | Registry de Execution Environments (padrão: host do `AUTOMATION_HUB_URL`) |
| `AAP_CONTROLLER_URL` | URL do Ansible Automation Platform |
| `ANSIBLE_NAVIGATOR_EXECUTION_ENVIRONMENT_IMAGE` | Imagem EE padrão do `ansible-navigator` |

## Build

```
podman login registry.redhat.io
podman-compose -f image/compose.yaml --env-file image/.env build
```

## Test

```
podman run --rm --entrypoint /bin/bash quay.io/${QUAY_ORG}/${IMAGE_NAME}:${IMAGE_TAG} -lc '
  echo "== Ansible =="; ansible --version;
  ansible-lint --version; ansible-navigator --version; ansible-builder --version;
  molecule --version; ansible-creator --version;
  echo "== base intacta =="; /usr/bin/python3 -V; podman-compose --version;
  echo "== Environment =="; devspaces-environment;
'
```

## Push

```
podman login quay.io
podman-compose -f image/compose.yaml --env-file image/.env push
```
