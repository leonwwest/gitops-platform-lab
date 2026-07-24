#!/usr/bin/env bash
set -euo pipefail

image="${IMAGE:-gitops-platform-lab-demo:local}"
container="${CONTAINER_NAME:-gitops-platform-lab-demo-verify}"
port="${PORT:-18080}"

command -v docker >/dev/null 2>&1 || {
  echo "docker is required for container verification" >&2
  exit 1
}

cleanup() {
  docker rm -f "${container}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker build --tag "${image}" .

runtime_uid="$(docker run --rm --entrypoint id "${image}" -u)"
if [[ "${runtime_uid}" == "0" ]]; then
  echo "container must not run as root" >&2
  exit 1
fi

cleanup
docker run --detach \
  --name "${container}" \
  --publish "127.0.0.1:${port}:8080" \
  --env APP_ENV=container-test \
  --env APP_VERSION=container-test \
  "${image}" >/dev/null

for _ in {1..30}; do
  if curl --fail --silent "http://127.0.0.1:${port}/healthz" >/dev/null; then
    break
  fi
  sleep 1
done

health="$(curl --fail --silent "http://127.0.0.1:${port}/healthz")"
info="$(curl --fail --silent "http://127.0.0.1:${port}/api/v1/info")"
metrics="$(curl --fail --silent "http://127.0.0.1:${port}/metrics")"

[[ "${health}" == '{"status":"ok"}' ]]
[[ "${info}" == *'"environment":"container-test"'* ]]
[[ "${info}" == *'"version":"container-test"'* ]]
[[ "${metrics}" == *"demo_http_requests_total"* ]]

echo "container verification passed: ${image} (uid ${runtime_uid})"
