# Desired State recovery exercise

This exercise proves that the rebuild authority is Git. The snapshots below are diagnostic
evidence only; they are never applied back to the cluster.

## Before the exercise

1. Run `make verify` and confirm Argo CD reports `Synced / Healthy`.
2. Run `make recovery-snapshot` to capture the Desired State, Argo revision and Running State.
3. Record the current Git commit and local tool versions.

## Loss simulation and rebuild

Delete only the disposable k3d cluster with `make local-down`. Then run `make platform-up` from
the recorded Git revision. Argo CD recreates the managed workload from version-controlled
Desired State; the observability installer recreates the lab-only telemetry stack.

## Acceptance criteria

- Argo CD reaches `Synced / Healthy` without an imperative workload restore.
- the Deployment becomes Available and the smoke test succeeds;
- Prometheus can scrape application metrics;
- logs and traces appear after new test traffic;
- `make recovery-verify` exits successfully.

Production recovery would additionally require encrypted off-cluster data backups, external
secret recovery, tested RPO/RTO targets and multi-zone control-plane design. This stateless lab
does not pretend to validate those concerns.
