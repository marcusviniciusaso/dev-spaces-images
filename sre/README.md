# custom-udi-sre

Imagem de workspace SRE baseada na `custom-udi`, com ferramentas de operacao
para OpenShift/Kubernetes: **oc**, **kubectl** e **Helm**.

| Ferramenta | Origem |
|------------|--------|
| oc         | `devspaces-sre` image |
| kubectl    | `devspaces-sre` image |
| helm       | `devspaces-sre` image |

## Build image

```
podman-compose -f image/compose.yaml --env-file image/.env build
```

## Test

```
podman run --rm -it quay.io/${QUAY_ORG}/${IMAGE_NAME}:${IMAGE_TAG} bash -lc '
  cat /etc/devspaces-linux-release
  devspaces-environment
  oc version --client
  kubectl version --client
  helm version
'
```

## Push to Quay

```
podman login quay.io
podman-compose -f image/compose.yaml --env-file image/.env push
```
