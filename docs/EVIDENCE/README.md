# Evidence

Two artifacts here are produced without a running cluster and are committed:

- `rendered-manifests.yaml` - full output of `kubectl kustomize manifests/overlays/prod`,
  showing every object the cluster runs with the prod image tags and domain applied.
- `terraform-validate.log` - `terraform validate` on the infra, confirming the config is valid.

The screenshots/logs below need a running cluster. They could not be captured for this
submission: the AWS account used has an EC2 vCPU quota of 1, the increase was declined,
and no funded or free 3-node cluster was available (see ../../SUBMISSION.md). Each is
listed with what it proves and the command that produces it, so a grader with cluster
access can reproduce them via the RUNBOOK.

- nodes-ready.png - `kubectl get nodes -o wide`, 3 nodes Ready (server + 2 agents)
- pods-spread.png - `kubectl -n taskapp get pods -o wide`, replicas on different nodes
- tls-valid.png - `curl -vI https://taskapp.rufaiahmed.com`, valid Let's Encrypt cert
- pvc-persist.log - data survives a Postgres pod delete (RUNBOOK failure recovery)
- zero-downtime.log - unbroken 200s during a rollout (`scripts/zero-downtime-check.sh`)
- hpa-scale.png - backend replicas climbing under load (`scripts/load-test.sh`)
- argocd-synced.png - Argo CD apps Synced + Healthy
- failover.png - app still serving after `kubectl drain capstone-phoenix-worker-1`
