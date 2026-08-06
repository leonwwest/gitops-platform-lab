# SLO alert runbook

## Service objective

The lab models a 99.5% monthly availability objective for successful HTTP responses. The
Prometheus rules are deliberately small enough to inspect: a five-minute error ratio above 5%
is treated as fast error-budget consumption. This is an educational approximation, not a claim
about a production service.

## First five minutes

1. Confirm the alert and its labels in Prometheus.
2. Check Argo CD health and sync status with `make gitops-status`.
3. Compare the current image, replicas and environment with Git Desired State.
4. Inspect Grafana request rate/error panels, Loki logs and a failing trace in Jaeger.
5. Do not patch the managed Deployment as the normal recovery path. Revert or correct Git and
   let reconciliation restore the Running State.

## Decision path

- `up == 0`: verify pods, probes, endpoints and NetworkPolicy before application debugging.
- Elevated 5xx with healthy pods: correlate structured logs and traces by request ID.
- A recent Promotion is correlated: revert the Git change and observe Argo CD reconciliation.
- No recent Promotion: use the Failure Exercise runbook to isolate infrastructure from code.

## Closure evidence

Record the Git commit, Argo CD sync revision, alert start/end, suspected cause, recovery action
and one prevention task. Capture evidence with `make recovery-snapshot` and validate the restored
service with `make recovery-verify`.
