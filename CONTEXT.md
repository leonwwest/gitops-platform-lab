# GitOps Platform Lab

A learning and portfolio environment for understanding and demonstrating a complete software delivery and operations path.

## Language

**Platform Lab**:
The complete learning environment in which a workload is delivered, observed and operated through a reproducible workflow.
_Avoid_: Playground, test project

**Demo Service**:
The deliberately small workload used to exercise the Platform Lab without introducing unrelated product complexity.
_Avoid_: Business application, production application

**Desired State**:
The version-controlled declaration of how the Demo Service and its operating environment should behave.
_Avoid_: Deployment script, live configuration

**Reconciliation**:
The repeated comparison and correction that brings the Running State back to the Desired State.
_Avoid_: One-time deployment, sync script

**Running State**:
The resources and configuration that currently exist in the local cluster.
_Avoid_: Current files, live code

**Promotion**:
A reviewed change to the Desired State that moves a verified Demo Service version into an environment.
_Avoid_: Manual deployment, direct cluster edit

**Operational Signal**:
An externally observable metric, log or trace used to understand the health and behaviour of the Demo Service.
_Avoid_: Debug output, console print

**Failure Exercise**:
A documented, reversible disturbance used to practise detection, diagnosis and recovery inside the Platform Lab.
_Avoid_: Chaos, breaking the cluster
