# custom-udi-java21-selenium

## Build image

```
podman-compose -f image/compose.yaml --env-file image/.env build
```

## Test

```bash
podman run --rm quay.io/${QUAY_ORG}/${IMAGE_NAME}:${IMAGE_TAG} bash -lc '
  echo "== Java =="; java -version;
  echo "== Maven =="; mvn -version | head -n 5;
  echo "== Chrome =="; chrome --version;
  echo "== Chromedriver =="; chromedriver --version;
  echo "== Library check (must be empty) ==";
  ldd /opt/chrome/current/chrome | grep "not found" || echo "OK: all libs resolved";
  echo "== Headless smoke test ==";
  chrome --headless=new --no-sandbox --disable-dev-shm-usage --disable-gpu --dump-dom about:blank | head -5;
'
```

## Push to Quay

```
podman login quay.io

podman-compose -f image/compose.yaml --env-file image/.env push
```
