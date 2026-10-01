# custom-udi-terraform

Imagem de workspace Terraform baseada na `custom-udi`, com várias versões do Terraform gerenciadas
pelo tfenv.

| Ferramenta | Versão | Origem |
| --- | --- | --- |
| tfenv | 3.2.2 | GitHub (`/opt/tfenv`) |
| Terraform | 1.11.4, 1.12.2, 1.13.5, 1.14.9 (padrão) | `tfenv install` (releases.hashicorp.com, SHA256 conferido) |
| tflint | 0.64.0 | GitHub (checksum conferido), ruleset `terraform` embutido |
| terraform-docs | 0.24.0 | GitHub (checksum conferido) |
| terratest | 2.0.0 (`modules/terraform/v2`) | proxy Go local em `/opt/terratest/goproxy` |
| Go | o da imagem base (≥ 1.26) | exigido pelo terratest |
| Providers `hashicorp/random` 3.9.1 e `hashicorp/local` 2.9.1 | embutidos | `/usr/share/terraform/plugins` |

**Versões do Terraform.** As versões ficam em `/opt/tfenv/versions` e a padrão em
`/opt/tfenv/version`. O `.bashrc` salva a escolha do `tfenv use` em
`/home/user/persistent/.tfenv/version` e a restaura ao abrir o terminal. Um `.terraform-version`
no projeto tem prioridade. `TFENV_AUTO_INSTALL=false`: o tfenv não baixa versões sem pedido.

**Sem rede.** Os providers do sample ficam num *implied local mirror* do Terraform, então o
`terraform init` do sample funciona sem configuração. Os módulos Go do terratest ficam num proxy
local (`GOPROXY=file:///opt/terratest/goproxy,https://proxy.golang.org,direct`), então o `go test`
do sample também funciona sem rede.

| Comando | O que faz |
| --- | --- |
| `devspaces-environment` | Mostra as versões das ferramentas e a conectividade com os repositórios |
| `devspaces-setup` | Configura o repositório corporativo de providers, de módulos Go e de releases do Terraform |
| `devspaces-linux-release` | Mostra a versão da imagem base |
| `tfenv list` / `tfenv use <versão>` | Lista as versões instaladas / troca a versão padrão |

Variáveis lidas pelos scripts (definidas no devfile):

| Variável | Uso |
| --- | --- |
| `ARTIFACTORY_TERRAFORM_URL` | Repositório Terraform (mirror de providers em `<url>/providers/` e registry de módulos) |
| `ARTIFACTORY_GO_URL` | Proxy de módulos Go, usado depois do proxy local |
| `ARTIFACTORY_TERRAFORM_RELEASES_URL` | Opcional; mirror de releases.hashicorp.com para `tfenv install` |

O `devspaces-setup` pede o usuário e o token uma vez e grava, em
`/home/user/persistent/.terraform.d/` (modo 600):

- `.netrc`: as credenciais, lidas pelo Go e pelo tfenv.
- `terraform.rc`: o `provider_installation`, com o mirror local (só os providers embutidos) e o mirror de rede (todos os outros). Assim, o `terraform init` do sample não depende do mirror de rede.
- `devspaces.env`: as variáveis `TF_CLI_CONFIG_FILE`, `TF_TOKEN_<host>`, `GOPROXY`, `NETRC` e `TFENV_REMOTE`, carregadas pelo `.bashrc`.

## Build

```
podman-compose -f image/compose.yaml --env-file image/.env build
```

## Test

```
podman run --rm --entrypoint /bin/bash quay.io/${QUAY_ORG}/${IMAGE_NAME}:${IMAGE_TAG} -lc '
  echo "== Terraform =="; tfenv list; terraform version;
  tflint --version; terraform-docs --version; go version;
  echo "== base intacta =="; /usr/bin/python3 -V; podman-compose --version;
  echo "== Environment =="; devspaces-environment;
'
```

> No Mac com Apple Silicon (emulação amd64 via Rosetta), os binários do Terraform 1.11, 1.12 e
> 1.13 (compilados com Go ≤ 1.24) falham com `fatal error: lfstack.push`. É uma limitação da
> emulação: valide essas versões no cluster.

## Push

```
podman login quay.io
podman-compose -f image/compose.yaml --env-file image/.env push
```
