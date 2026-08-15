# Multi-window error-budget alerts

The Platform Lab pages only when both the 5-minute and 1-hour availability burn rates cross their
thresholds. A single short error spike remains observable without automatically becoming a page;
sustained fast budget consumption does page and links directly to the SLO runbook.

The thresholds are intentionally inspectable and exercised with deterministic synthetic request
counts. They demonstrate the decision model, not a production SLO calibrated from user traffic.
