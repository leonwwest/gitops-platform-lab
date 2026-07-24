# Git is the deployment boundary

The Platform Lab uses Git as the only source of Desired State and Argo CD as the reconciler. CI may test and build a candidate, but it does not imperatively deploy application resources; a reviewed manifest change performs Promotion. This preserves the central GitOps distinction between validating software and reconciling the Running State, even though the first environment is a local k3d cluster.
