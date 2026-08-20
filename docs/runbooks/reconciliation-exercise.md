# Runbook: Desired State reconciliation exercise

## Goal

Demonstrate Argo CD self-healing with inspectable evidence. The exercise introduces one reversible difference in the Running State, forces a comparison and verifies that Argo CD restores the replica count declared in Git without changing the Git revision.

## Preconditions

Start the local GitOps environment and confirm its baseline:

```bash
make gitops-up
make gitops-status
git status --short
```

Expected: the Application uses `deploy/overlays/local`, reports `Synced / Healthy`, the Deployment has one ready replica and the repository has no unexpected changes.

Do not run this exercise against the production-like overlay. Its HorizontalPodAutoscaler owns the replica count, so manual scaling would test a different controller boundary.

## Exercise

Running State mutation is deliberately opt-in:

```bash
CONFIRM_RECONCILIATION_EXERCISE=YES make reconciliation-exercise
```

The script performs these checks and actions:

1. Verifies the healthy local baseline.
2. Records the reconciled Git revision.
3. Scales the live Deployment from one to two replicas without changing Git.
4. Requests an Argo CD refresh.
5. Waits for one ready replica and `Synced / Healthy` status.
6. Confirms that the Git revision did not change.

Argo CD remains the recovery mechanism. The script never applies a workload manifest or imperatively scales the Deployment back down.

## Evidence

Successful execution writes `.local/reconciliation-exercise.md`. The ignored local evidence records the timestamps, stable Git revision, injected replica count, restored replica count and final health state.

Inspect the result:

```bash
make reconciliation-status
cat .local/reconciliation-exercise.md
```

The key result is not merely that the Deployment returns to one replica. It is that reconciliation restores the Desired State while the source revision remains identical.

## Troubleshooting

If restoration times out, inspect the ownership boundary before changing anything else:

```bash
kubectl -n argocd get application/demo-service -o yaml
kubectl -n platform-lab get deployment/demo-service -o yaml
kubectl -n argocd logs statefulset/argocd-application-controller --tail=100
```

Check that automated sync and `selfHeal` remain enabled, the Application belongs to the `platform-lab` AppProject and the project permits `apps/Deployment` in the `platform-lab` Namespace.
