# custom-udi-ansible

## Build image

```
podman-compose -f image/compose.yaml --env-file image/.env build
```

## Test

```
podman run --rm quay.io/${QUAY_ORG}/${IMAGE_NAME}:${IMAGE_TAG} bash -lc '
  ansible --version
  ansible-lint --version
  ansible-navigator --version || true
  molecule --version
  ansible-galaxy collection list
  oc version --client
  kubectl version --client
  helm version
  podman version
'
```

## Push to Quay

```
podman login quay.io

podman-compose -f image/compose.yaml --env-file image/.env push
```
