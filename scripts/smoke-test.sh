#!/usr/bin/env bash
set -euo pipefail

base_url="${BASE_URL:-http://127.0.0.1:8080}"

for _ in {1..60}; do
  if curl --fail --silent "${base_url}/readyz" >/dev/null; then
    break
  fi
  sleep 1
done

health="$(curl --fail --silent "${base_url}/healthz")"
readiness="$(curl --fail --silent "${base_url}/readyz")"
work="$(curl --fail --silent "${base_url}/api/v1/work?duration_ms=5")"
failure_status="$(
  curl --silent --output /dev/null --write-out "%{http_code}" \
    "${base_url}/api/v1/work?duration_ms=1&fail=true"
)"
metrics="$(curl --fail --silent "${base_url}/metrics")"

[[ "${health}" == '{"status":"ok"}' ]]
[[ "${readiness}" == '{"status":"ready"}' ]]
[[ "${work}" == '{"status":"completed","duration_ms":5}' ]]
[[ "${failure_status}" == "503" ]]
[[ "${metrics}" == *"demo_http_requests_total"* ]]

echo "runtime smoke test passed: ${base_url}"
