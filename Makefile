PYTHON ?= .venv/bin/python
PIP ?= .venv/bin/pip
IMAGE ?= gitops-platform-lab-demo:local

.PHONY: setup test lint format-check manifests verify run image container-verify local-up gitops-up gitops-status observability-up observability-verify observability-password failure-inject failure-status failure-recover smoke local-down

setup:
	python3 -m venv .venv
	$(PIP) install --disable-pip-version-check -r requirements-dev.txt

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

verify: lint format-check manifests test

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

smoke:
	./scripts/smoke-test.sh

local-down:
	./scripts/cleanup-local.sh
