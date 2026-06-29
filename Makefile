SHELL := /bin/bash
KUBECONFIG ?= $(PWD)/infra/ansible/kubeconfig
export KUBECONFIG
TF := terraform -chdir=infra/terraform
ARGOCD_VERSION ?= v2.13.2

.PHONY: help bootstrap infra cluster nodes argocd gitops build evidence load-test destroy

help: ## list targets
	@grep -hE '^[a-zA-Z_-]+:.*?##' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-16s\033[0m %s\n",$$1,$$2}'

bootstrap: ## create the S3+DynamoDB remote-state backend (run once)
	terraform -chdir=infra/terraform/bootstrap init
	terraform -chdir=infra/terraform/bootstrap apply

infra: ## provision the 3 nodes (writes the Ansible inventory)
	$(TF) init
	$(TF) apply

cluster: ## install k3s across the nodes + fetch kubeconfig
	cd infra/ansible && ansible-galaxy collection install -r requirements.yml && ansible-playbook site.yml

nodes: ## show cluster nodes
	kubectl get nodes -o wide

argocd: ## install Argo CD into the cluster
	kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/$(ARGOCD_VERSION)/manifests/install.yaml
	kubectl -n argocd rollout status deploy/argocd-server

gitops: ## hand the cluster to Argo CD (app-of-apps)
	kubectl apply -f gitops/root-app.yaml

build: ## render the prod manifests locally (no cluster needed)
	kubectl kustomize manifests/overlays/prod

evidence: ## snapshot cluster state into docs/EVIDENCE
	./scripts/collect-evidence.sh

load-test: ## drive load to trigger the HPA: make load-test URL=https://taskapp.<you>.com
	./scripts/load-test.sh $(URL)

destroy: ## tear the nodes down
	$(TF) destroy
