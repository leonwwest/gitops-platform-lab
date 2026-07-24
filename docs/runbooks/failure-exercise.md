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

The script points the Argo CD Application at the version-controlled failure overlay. Automated reconciliation stays enabled, and Argo CD—not the script—changes the Demo Service. The command waits for `Synced / Healthy` with `APP_ENV=failure`; a request to `/api/v1/work` must then return HTTP 503.

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
5. **GitOps:** Argo CD shows the `deploy/overlays/failure` source as `Synced / Healthy`. The degraded behaviour is intentional Desired State for this guarded drill.

This distinguishes service degradation from a platform outage.

## Diagnose

```bash
kubectl -n platform-lab get deployment/demo-service -o yaml |
  rg -n "APP_ENV|image:|readyReplicas"
kubectl -n platform-lab logs deployment/demo-service --tail=20
make failure-status
```

Expected cause: the Argo CD Application selected the version-controlled failure overlay, which changed `APP_ENV` from `local` to `failure`.

## Recover

```bash
make failure-recover
```

Recovery reapplies the version-controlled healthy Argo CD Application and waits until:

- Application status is `Synced`
- Application health is `Healthy`
- `APP_ENV` is restored to `local`
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
