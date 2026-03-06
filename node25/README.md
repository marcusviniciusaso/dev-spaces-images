# custom-udi-node25

## Build image

```
podman-compose -f image/compose.yaml --env-file image/.env build
```

## Test

```
podman run --rm quay.io/${QUAY_ORG}/${IMAGE_NAME}:${IMAGE_TAG} bash -lc '
  echo "== Node =="; node -v;
  echo "== npm =="; npm -v;
  echo "== Nest CLI =="; nest --version || true;
'
```

## Push to Quay

```
podman login quay.io
podman-compose -f image/compose.yaml --env-file image/.env push
```
