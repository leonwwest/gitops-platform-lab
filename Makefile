PYTHON ?= .venv/bin/python
PIP ?= .venv/bin/pip
VENV_PYTHON ?= python3.12
VENV_STAMP := .venv/.requirements-installed
IMAGE ?= gitops-platform-lab-demo:local

.PHONY: setup test lint format-check manifests verify slo-exercise run image container-verify local-up gitops-up platform-up gitops-status observability-up observability-verify observability-password failure-inject failure-status failure-recover recovery-snapshot recovery-verify smoke local-down

setup: $(VENV_STAMP)

$(VENV_STAMP): requirements.txt requirements-dev.txt constraints.lock.txt pyproject.toml
	@if [ ! -x "$(PYTHON)" ]; then \
		command -v "$(VENV_PYTHON)" >/dev/null 2>&1 || { \
			echo "$(VENV_PYTHON) is required to create the Python 3.12 environment" >&2; \
			exit 1; \
		}; \
		"$(VENV_PYTHON)" -m venv .venv; \
	fi
	$(PIP) install --disable-pip-version-check -c constraints.lock.txt -r requirements-dev.txt
	@touch $(VENV_STAMP)

test:
	$(PYTHON) -m pytest

lint:
	$(PYTHON) -m ruff check .

format-check:
	$(PYTHON) -m ruff format --check .

manifests:
	kubectl kustomize deploy/overlays/local >/dev/null
	kubectl kustomize deploy/overlays/failure >/dev/null
	kubectl kustomize deploy/overlays/production >/dev/null

verify: setup lint format-check manifests test

slo-exercise:
	$(PYTHON) -m tools.slo_burn_rate

run:
	$(PYTHON) -m uvicorn app.main:app --host 0.0.0.0 --port 8080

image:
	docker build --tag $(IMAGE) .

container-verify:
	IMAGE=$(IMAGE) ./scripts/verify-container.sh

local-up:
	IMAGE=$(IMAGE) ./scripts/bootstrap-local.sh

gitops-up:
	APPLY_MODE=none IMAGE=$(IMAGE) ./scripts/bootstrap-local.sh
	./scripts/install-argocd.sh
	./scripts/smoke-test.sh

platform-up:
	$(MAKE) verify
	$(MAKE) gitops-up
	$(MAKE) observability-up
	$(MAKE) observability-verify

gitops-status:
	kubectl get application/demo-service --namespace argocd
	kubectl get deployment,pod,service --namespace platform-lab

observability-up:
	./scripts/install-observability.sh

observability-verify:
	./scripts/verify-observability.sh

observability-password:
	kubectl get secret/grafana-admin --namespace observability --output=jsonpath='{.data.admin-password}' | base64 --decode
	@echo

failure-inject:
	./scripts/failure-exercise.sh inject

failure-status:
	./scripts/failure-exercise.sh status

failure-recover:
	./scripts/failure-exercise.sh recover

recovery-snapshot:
	./scripts/recovery-evidence.sh snapshot

recovery-verify:
	./scripts/recovery-evidence.sh verify

smoke:
	./scripts/smoke-test.sh

local-down:
	./scripts/cleanup-local.sh
