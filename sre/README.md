# custom-udi-sre

## Build image

```
podman-compose -f image/compose.yaml --env-file image/.env build
```

## Test

```
podman run --rm -it quay.io/${QUAY_ORG}/${IMAGE_NAME}:${IMAGE_TAG} bash -lc '
  cat /etc/devspaces-linux-release
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
