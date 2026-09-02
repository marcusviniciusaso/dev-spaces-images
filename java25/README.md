# custom-udi-java25

| Ferramenta | Versão |
| --- | --- |
| OpenJDK | 25 |
| Maven | 3.9.12 |
| Gradle | 9.3.1 |
| Spring Boot CLI | 4.0.3 |

## Build

```
podman-compose -f image/compose.yaml --env-file image/.env build
```

## Test

```
podman run --rm --entrypoint /bin/bash quay.io/${QUAY_ORG}/${IMAGE_NAME}:${IMAGE_TAG} -lc '
  echo "== Java =="; java -version;
  echo "== Maven =="; mvn -version | head -n 5;
  echo "== Gradle =="; gradle --version | head -n 8;
  echo "== Spring Boot CLI =="; spring --version;
'
```

## Push

```
podman login quay.io
podman-compose -f image/compose.yaml --env-file image/.env push
```
