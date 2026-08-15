"""Evaluate a deterministic multi-window SLO Failure Exercise."""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class WindowResult:
    ratio: float
    burn_rate: float


def evaluate_window(window: dict[str, int], error_budget: float) -> WindowResult:
    requests = window["requests"]
    errors = window["errors"]
    if requests <= 0 or errors < 0 or errors > requests:
        raise ValueError("requests must be positive and errors must be between zero and requests")
    ratio = errors / requests
    return WindowResult(ratio=ratio, burn_rate=ratio / error_budget)


def evaluate_scenario(scenario: dict[str, Any], config: dict[str, Any]) -> dict[str, Any]:
    error_budget = 1 - config["objective"]
    short = evaluate_window(scenario["short"], error_budget)
    long = evaluate_window(scenario["long"], error_budget)
    breached = (
        short.burn_rate > config["thresholds"]["short_window"]
        and long.burn_rate > config["thresholds"]["long_window"]
    )
    return {"name": scenario["name"], "short": short, "long": long, "breached": breached}


def render_evidence(config: dict[str, Any]) -> str:
    results = [evaluate_scenario(scenario, config) for scenario in config["scenarios"]]
    rows = []
    for result in results:
        state = "PAGE" if result["breached"] else "OK"
        rows.append(
            f"| {result['name']} | {result['short'].ratio:.2%} | "
            f"{result['short'].burn_rate:.1f}x | {result['long'].ratio:.2%} | "
            f"{result['long'].burn_rate:.1f}x | **{state}** |"
        )
    return "\n".join(
        [
            "# SLO burn-rate exercise evidence",
            "",
            "Deterministic, synthetic request counts exercise the same 99.5% objective and",
            "multi-window thresholds encoded in `observability/slo-rules.yaml`.",
            "",
            "| Scenario | 5m errors | 5m burn | 1h errors | 1h burn | Result |",
            "|---|---:|---:|---:|---:|---|",
            *rows,
            "",
            "The middle scenario breaches both windows; the final scenario demonstrates recovery.",
            "Running State recovery still happens through a reviewed Git change and Argo CD",
            "Reconciliation, as described in the Failure Exercise runbook.",
            "",
        ]
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", type=Path, default=Path("fixtures/slo-burn-rate.json"))
    parser.add_argument("--output", type=Path, default=Path("docs/evidence/slo-burn-rate.md"))
    args = parser.parse_args()
    config = json.loads(args.fixture.read_text(encoding="utf-8"))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(render_evidence(config), encoding="utf-8")
    print(f"SLO burn-rate evidence written to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
