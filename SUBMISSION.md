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

## Live evidence (captured on a local k3d cluster)

The AWS account's EC2 vCPU quota was capped at 1 and the increase was declined,
with no funded or free cloud available, so the cluster could not run on real EC2
nodes. To still demonstrate it working, I brought up a real 3-node k3s cluster
locally with k3d (one server + two agents) and captured the logs in
docs/EVIDENCE/: 3 nodes Ready, replicas spread across nodes, the app serving end
to end (`/api/health` reports the database connected), the HPA scaling the backend
2 -> 6 on CPU and back to 2 idle, a zero-downtime backend rollout (240/240 requests
returned 200), Postgres data surviving a pod delete, node failover via drain, and
Argo CD owning the app (Synced + Healthy). The nodes are containers rather than
separate VMs, and the one thing not capturable locally is a real-domain Let's
Encrypt cert, which needs a publicly reachable ingress for the HTTP-01 challenge.
Nothing is faked or staged.

## Reproducing it

docs/RUNBOOK.md takes a funded account from zero to a running HTTPS cluster
(make bootstrap -> make infra -> make cluster -> make argocd -> make gitops), about 15
minutes. docs/ARCHITECTURE.md covers the design and the single-server assumptions it
fixes; docs/COST.md itemizes the cost.
