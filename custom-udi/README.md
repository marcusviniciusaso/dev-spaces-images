# custom-udi

## Build image

```
podman login registry.redhat.io

podman-compose -f image/compose.yaml --env-file image/.env build
```

## Test

```
podman run --rm -it quay.io/${QUAY_ORG}/${IMAGE_NAME}:${IMAGE_TAG} bash -lc '
  cat /etc/devspaces-linux-release
  az version | head -n 20
  oc version --client
  kubectl version --client
  helm version
  kind version
  cekit --version || true
  podman version
  podman-compose version
  podman-mcp --version || pip3 show podman-mcp
  pip3 show mcp | grep Version
'
```

## Push to Quay

```
podman login quay.io

podman-compose -f image/compose.yaml --env-file image/.env push
```
