# custom-udi-java8

| Ferramenta | Versão |
| --- | --- |
| OpenJDK | 8 |
| Maven | 3.9.9 (da base) |
| Gradle | 7.6.6 |
| Spring Boot CLI | 2.7.18 |

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
