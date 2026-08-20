#!/usr/bin/env bash
set -euo pipefail

action="${1:-status}"
application="demo-service"
namespace="platform-lab"
deployment="demo-service"
expected_replicas="${EXPECTED_REPLICAS:-1}"
timeout_seconds="${RECONCILIATION_TIMEOUT_SECONDS:-300}"
evidence_file="${EVIDENCE_FILE:-.local/reconciliation-exercise.md}"

command -v kubectl >/dev/null 2>&1 || {
  echo "kubectl is required" >&2
  exit 1
}

application_value() {
  kubectl get application/"${application}" \
    --namespace argocd \
    --output="jsonpath={$1}" 2>/dev/null || true
}

deployment_value() {
  kubectl get deployment/"${deployment}" \
    --namespace "${namespace}" \
    --output="jsonpath={$1}" 2>/dev/null || true
}

show_status() {
  local sync health revision replicas ready source_path
  sync="$(application_value '.status.sync.status')"
  health="$(application_value '.status.health.status')"
  revision="$(application_value '.status.sync.revision')"
  source_path="$(application_value '.spec.source.path')"
  replicas="$(deployment_value '.spec.replicas')"
  ready="$(deployment_value '.status.readyReplicas')"

  echo "application=${application} sync=${sync:-unknown} health=${health:-unknown} revision=${revision:-unknown}"
  echo "source=${source_path:-unknown} deployment=${deployment} replicas=${replicas:-0} ready=${ready:-0}"
}

wait_for_desired_state() {
  local deadline=$((SECONDS + timeout_seconds))
  local sync health replicas ready
  while ((SECONDS < deadline)); do
    sync="$(application_value '.status.sync.status')"
    health="$(application_value '.status.health.status')"
    replicas="$(deployment_value '.spec.replicas')"
    ready="$(deployment_value '.status.readyReplicas')"
    if [[ "${sync}" == "Synced" \
      && "${health}" == "Healthy" \
      && "${replicas}" == "${expected_replicas}" \
      && "${ready}" == "${expected_replicas}" ]]; then
      return 0
    fi
    sleep 5
  done

  show_status
  echo "Desired State was not restored within ${timeout_seconds}s" >&2
  return 1
}

run_exercise() {
  local before_revision after_revision source_path injected_replicas started_at completed_at

  if [[ "${CONFIRM_RECONCILIATION_EXERCISE:-}" != "YES" ]]; then
    echo "Running State mutation is opt-in." >&2
    echo "Run: CONFIRM_RECONCILIATION_EXERCISE=YES make reconciliation-exercise" >&2
    exit 2
  fi

  source_path="$(application_value '.spec.source.path')"
  if [[ "${source_path}" != "deploy/overlays/local" ]]; then
    echo "Exercise requires the local Desired State; found: ${source_path:-unknown}" >&2
    exit 1
  fi

  wait_for_desired_state
  before_revision="$(application_value '.status.sync.revision')"
  [[ -n "${before_revision}" ]]
  started_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  injected_replicas=$((expected_replicas + 1))

  echo "Injecting replica drift: ${expected_replicas} -> ${injected_replicas}"
  kubectl scale deployment/"${deployment}" \
    --namespace "${namespace}" \
    --replicas="${injected_replicas}"
  kubectl annotate application/"${application}" \
    --namespace argocd \
    argocd.argoproj.io/refresh=hard \
    --overwrite

  wait_for_desired_state
  after_revision="$(application_value '.status.sync.revision')"
  if [[ "${after_revision}" != "${before_revision}" ]]; then
    echo "Git revision changed during the exercise" >&2
    exit 1
  fi

  completed_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  mkdir -p "$(dirname "${evidence_file}")"
  printf '%s\n' \
    "# Reconciliation exercise evidence" \
    "" \
    "- Started: ${started_at}" \
    "- Completed: ${completed_at}" \
    "- Git revision: ${before_revision}" \
    "- Injected Running State replicas: ${injected_replicas}" \
    "- Restored Desired State replicas: ${expected_replicas}" \
    "- Result: Synced / Healthy without a Git revision change" \
    >"${evidence_file}"

  show_status
  echo "Reconciliation evidence written to ${evidence_file}"
}

case "${action}" in
  run)
    run_exercise
    ;;
  status)
    show_status
    ;;
  *)
    echo "Usage: $0 {run|status}" >&2
    exit 2
    ;;
esac
