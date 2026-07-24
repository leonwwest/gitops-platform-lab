from __future__ import annotations

import json
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
OBSERVABILITY = ROOT / "observability"


def test_observability_chart_versions_are_explicitly_pinned() -> None:
    versions = {}
    for line in (OBSERVABILITY / "versions.env").read_text().splitlines():
        if line and not line.startswith("#"):
            key, value = line.split("=", maxsplit=1)
            versions[key] = value

    assert versions == {
        "PROMETHEUS_CHART_VERSION": "29.19.0",
        "GRAFANA_CHART_VERSION": "10.5.15",
        "LOKI_CHART_VERSION": "7.1.0",
        "PROMTAIL_CHART_VERSION": "6.17.1",
        "JAEGER_CHART_VERSION": "4.11.1",
    }


def test_loki_is_an_explicit_single_binary_learning_deployment() -> None:
    values = yaml.safe_load((OBSERVABILITY / "loki-values.yaml").read_text())

    assert values["deploymentMode"] == "SingleBinary"
    assert values["loki"]["auth_enabled"] is False
    assert values["loki"]["commonConfig"]["replication_factor"] == 1
    assert values["loki"]["storage"]["type"] == "filesystem"
    assert values["loki"]["useTestSchema"] is True
    assert values["singleBinary"]["replicas"] == 1
    assert values["chunksCache"]["enabled"] is False
    assert values["resultsCache"]["enabled"] is False


def test_grafana_dashboard_covers_request_rate_errors_latency_and_logs() -> None:
    config_map = yaml.safe_load((OBSERVABILITY / "grafana-dashboard.yaml").read_text())
    dashboard = json.loads(config_map["data"]["platform-lab.json"])
    queries = [
        target["expr"]
        for panel in dashboard["panels"]
        for target in panel.get("targets", [])
        if "expr" in target
    ]

    assert any("demo_http_requests_total" in query and "rate(" in query for query in queries)
    assert any('status=~"5.."' in query for query in queries)
    assert any("histogram_quantile" in query for query in queries)
    assert any('{namespace="platform-lab"' in query and "| json" in query for query in queries)


def test_local_workload_exports_traces_to_jaeger_otlp() -> None:
    patch = yaml.safe_load(
        (ROOT / "deploy" / "overlays" / "local" / "deployment-patch.yaml").read_text()
    )
    environment = {
        entry["name"]: entry["value"]
        for entry in patch["spec"]["template"]["spec"]["containers"][0]["env"]
    }

    assert environment["OTEL_EXPORTER_OTLP_ENDPOINT"] == (
        "http://jaeger.observability.svc.cluster.local:4318"
    )
