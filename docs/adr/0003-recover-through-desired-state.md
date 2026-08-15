# Recover through Desired State

The Failure Exercise recovers by returning the Argo CD Application to the healthy version-controlled
overlay. Operators do not patch the managed Deployment or apply a captured Running State snapshot.

This makes the recovery repeatable and preserves Git as the audit trail. It also means an incorrect
Desired State must be corrected or reverted before Reconciliation can restore service behaviour.
