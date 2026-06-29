# Submission notes

Capstone Phoenix: TaskApp on a multi-node k3s cluster, provisioned with Terraform,
configured with Ansible, deployed with kustomize, and reconciled by Argo CD.

## What is real and verifiable from this repo

- Modular Terraform (network / security_group / compute) with live S3 + DynamoDB
  remote state. I applied it to a real AWS account, so the VPC, two public subnets,
  the least-privilege security group (6443 and node ports are not internet-facing),
  and the SSH keypair exist. `terraform validate` passes (docs/EVIDENCE/terraform-validate.log).
- Idempotent Ansible roles (hardening, k3s_server, k3s_agent) that install k3s and
  join the agents.
- kustomize base + prod overlay: namespace, ConfigMap/Secret split, Postgres
  StatefulSet + PVC, backend and frontend Deployments, the run-once migration Job,
  Ingress + cert-manager TLS, HPA, PDBs, NetworkPolicy, and securityContext. It
  builds cleanly; docs/EVIDENCE/rendered-manifests.yaml is the full output of
  `kubectl kustomize manifests/overlays/prod`.
- A complete Argo CD app-of-apps (sealed-secrets, cert-manager, ingress-nginx,
  cluster-issuer, taskapp) with documented sync waves.

## What is not included, and why

The live cluster and its evidence (the get-nodes, TLS, HPA-scaling, and Argo-synced
screenshots, plus the node-failover demo) are not here. The AWS account used is new and
its EC2 vCPU quota is 1; the increase request was declined, the program did not provide
credits, and no funded or free 3-node cluster was available, so standing up three real
nodes was not possible. Nothing has been faked or staged.

## Reproducing it

docs/RUNBOOK.md takes a funded account from zero to a running HTTPS cluster
(make bootstrap -> make infra -> make cluster -> make argocd -> make gitops), about 15
minutes. docs/ARCHITECTURE.md covers the design and the single-server assumptions it
fixes; docs/COST.md itemizes the cost.
