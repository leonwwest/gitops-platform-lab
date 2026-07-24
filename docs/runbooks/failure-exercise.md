# Runbook: controlled service failure

## Goal

Practise the complete incident loop: detect, scope, inspect evidence, recover to Git Desired State and verify. The exercise affects only `/api/v1/work`; health and readiness remain available so the platform itself stays observable.

## Preconditions

```bash
make gitops-status
make observability-verify
git status --short
```

Expected: Argo CD is `Synced / Healthy`, the Demo Service is reachable and the repository has no unexpected changes.

## Inject

Injection is guarded and cannot run from the Make target without explicit confirmation:

```bash
CONFIRM_FAILURE_EXERCISE=YES make failure-inject
```

The script temporarily disables automated reconciliation and applies the version-controlled failure overlay. A request to `/api/v1/work` must return HTTP 503.

## Observe

Generate a few requests:

```bash
for i in {1..5}; do
  curl -i "http://127.0.0.1:8080/api/v1/work?duration_ms=20"
done
```

Check:

1. **Scope:** `/healthz` and `/readyz` remain 200; `/api/v1/work` is affected.
2. **Metrics:** `demo_http_requests_total{status="503"}` rises.
3. **Logs:** Loki shows `status=503`, request ID and duration.
4. **Traces:** Jaeger shows spans for the work endpoint.
5. **GitOps:** Argo CD shows `OutOfSync`, because Running State differs from Git.

This distinguishes service degradation from a platform outage.

## Diagnose

```bash
kubectl -n platform-lab get deployment/demo-service -o yaml |
  rg -n "FAILURE_MODE|image:|readyReplicas"
kubectl -n platform-lab logs deployment/demo-service --tail=20
make failure-status
```

Expected cause: `FAILURE_MODE=true` exists only in Running State from the controlled overlay.

## Recover

```bash
make failure-recover
```

Recovery reapplies the version-controlled Argo CD Application, restores automated reconciliation and waits until:

- Application status is `Synced`
- Application health is `Healthy`
- `FAILURE_MODE` is absent
- the full runtime smoke test passes

## Verify and close

```bash
make smoke
make observability-verify
make failure-status
```

Document the timeline, affected endpoint, evidence, root cause, recovery action and prevention. In a real incident, also record the incident owner, stakeholder updates and SLA impact.

## Abort path

If injection stops halfway, run `make failure-recover`. Recovery is safe to repeat because Git remains the healthy source of truth.
