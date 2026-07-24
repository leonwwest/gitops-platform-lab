#!/usr/bin/env bash
set -euo pipefail

action="${1:-status}"
application="demo-service"
namespace="platform-lab"
base_url="${BASE_URL:-http://127.0.0.1:8080}"

application_status() {
  kubectl get application/"${application}" \
    --namespace argocd \
    --output=custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,REVISION:.status.sync.revision
}

wait_for_git_state() {
  local deadline=$((SECONDS + 300))
  while ((SECONDS < deadline)); do
    sync="$(
      kubectl get application/"${application}" \
        --namespace argocd \
        --output=jsonpath='{.status.sync.status}' 2>/dev/null || true
    )"
    health="$(
      kubectl get application/"${application}" \
        --namespace argocd \
        --output=jsonpath='{.status.health.status}' 2>/dev/null || true
    )"
    app_environment="$(
      kubectl get deployment/demo-service \
        --namespace "${namespace}" \
        --output=jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="APP_ENV")].value}' \
        2>/dev/null || true
    )"
    if [[ "${sync}" == "Synced" && "${health}" == "Healthy" && "${app_environment}" == "local" ]]; then
      return 0
    fi
    sleep 5
  done
  application_status
  return 1
}

case "${action}" in
  inject)
    if [[ "${CONFIRM_FAILURE_EXERCISE:-}" != "YES" ]]; then
      echo "Failure injection is opt-in." >&2
      echo "Run: CONFIRM_FAILURE_EXERCISE=YES make failure-inject" >&2
      exit 2
    fi

    application_status
    kubectl patch application/"${application}" \
      --namespace argocd \
      --type=merge \
      --patch='{"spec":{"syncPolicy":{"automated":null}}}'
    kubectl apply \
      --server-side \
      --force-conflicts \
      --field-manager=failure-exercise \
      --kustomize deploy/overlays/failure
    kubectl rollout status deployment/demo-service \
      --namespace "${namespace}" \
      --timeout=180s

    status="$(
      curl --silent --output .local/failure-response.json --write-out "%{http_code}" \
        "${base_url}/api/v1/work?duration_ms=5"
    )"
    [[ "${status}" == "503" ]]
    echo "Failure Exercise active: /api/v1/work returns HTTP 503."
    echo "Observe the Operational Signals, then run: make failure-recover"
    ;;

  recover)
    kubectl apply --filename gitops/demo-service.yaml
    kubectl annotate application/"${application}" \
      --namespace argocd \
      argocd.argoproj.io/refresh=hard \
      --overwrite
    wait_for_git_state
    ./scripts/smoke-test.sh
    echo "Recovery complete: Git Desired State is Synced and Healthy."
    ;;

  status)
    application_status
    kubectl get deployment/demo-service \
      --namespace "${namespace}" \
      --output=custom-columns=NAME:.metadata.name,READY:.status.readyReplicas
    app_environment="$(
      kubectl get deployment/demo-service \
        --namespace "${namespace}" \
        --output=jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="APP_ENV")].value}'
    )"
    echo "APP_ENV=${app_environment:-unknown}"
    ;;

  *)
    echo "Usage: $0 {inject|recover|status}" >&2
    exit 2
    ;;
esac
