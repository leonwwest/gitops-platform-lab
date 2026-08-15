# SLO burn-rate exercise evidence

Deterministic, synthetic request counts exercise the same 99.5% objective and
multi-window thresholds encoded in `observability/slo-rules.yaml`.

| Scenario | 5m errors | 5m burn | 1h errors | 1h burn | Result |
|---|---:|---:|---:|---:|---|
| healthy baseline | 0.10% | 0.2x | 0.20% | 0.4x | **OK** |
| controlled breach | 10.00% | 20.0x | 5.00% | 10.0x | **PAGE** |
| recovered desired state | 0.20% | 0.4x | 0.40% | 0.8x | **OK** |

The middle scenario breaches both windows; the final scenario demonstrates recovery.
Running State recovery still happens through a reviewed Git change and Argo CD
Reconciliation, as described in the Failure Exercise runbook.
