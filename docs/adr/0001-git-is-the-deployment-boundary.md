# Git is the deployment boundary

The Platform Lab uses Git as the only source of Desired State and Argo CD as the reconciler. CI may test and build a candidate, but it does not imperatively deploy application resources; a reviewed manifest change performs Promotion. This preserves the central GitOps distinction between validating software and reconciling the Running State, even though the first environment is a local k3d cluster.

Two explicitly scoped learning operations are not Promotions:

- `make local-up` directly applies the local overlay before Argo CD is installed. It exists only to compare an imperative bootstrap with the later GitOps operating model.
- The guarded Failure Exercise changes the Argo CD Application source between two version-controlled overlays. Argo CD remains the only reconciler of the Demo Service; the operator does not directly edit workload resources.

Normal operation starts with `make platform-up` or `make gitops-up`. All subsequent application changes belong in Git.
