# custom-udi-python39

## Build image

```
podman-compose -f image/compose.yaml --env-file image/.env build
```

## Test

```
podman run --rm quay.io/${QUAY_ORG}/${IMAGE_NAME}:${IMAGE_TAG} bash -lc '
  echo "== Python =="; python3 --version;
  echo "== pip =="; pip3 --version;
  echo "== virtualenv =="; virtualenv --version || true;
'
```

## Push to Quay

```
podman login quay.io
podman-compose -f image/compose.yaml --env-file image/.env push
```
