# custom-udi-java17

## Build image

```
podman-compose -f image/compose.yaml --env-file image/.env build
```

## Test

```
podman run --rm quay.io/${QUAY_ORG}/${IMAGE_NAME}:${IMAGE_TAG} bash -lc '
  echo "== Java =="; java -version;
  echo "== Spring Boot CLI =="; spring --version;
  echo "== Maven =="; mvn -version | head -n 5;
  echo "== Gradle =="; gradle --version | head -n 8;
'
```

## Push to Quay

```
podman login quay.io

podman-compose -f image/compose.yaml --env-file image/.env push
```
