PYTHON ?= .venv/bin/python
PIP ?= .venv/bin/pip
IMAGE ?= gitops-platform-lab-demo:local

.PHONY: setup test lint format-check manifests verify run image container-verify local-up gitops-up gitops-status smoke local-down

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

smoke:
	./scripts/smoke-test.sh

local-down:
	./scripts/cleanup-local.sh
