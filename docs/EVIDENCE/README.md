# Evidence

These logs were captured against a real running 3-node k3s cluster. Because the
AWS account's vCPU quota was capped at 1 and the increase was declined (and no
funded or free cloud was available), the cluster was brought up locally with k3d
(k3s in Docker: one server + two agents). The nodes are containers rather than
separate VMs, but the Kubernetes behaviour (multi-node scheduling, autoscaling,
rolling updates, persistence, failover) is genuine. The same Ansible roles and
manifests provision real separate EC2 nodes on a funded account (see RUNBOOK).

Captured here:

- `nodes-ready.log` - 3 nodes Ready (1 control-plane + 2 agents).
- `pods-spread.log` - backend and frontend replicas land on different nodes.
- `app-health.log` - the app serves end to end: `/healthz` 200, and `/api/health`
  returns `database: connected` (frontend nginx proxies `/api` to the Flask
  backend, which queries Postgres).
- `hpa-scale.log` - the HPA scaled the backend 2 -> 4 -> 6 on `cpu utilization
  above target`, then back to 2 when idle (the autoscaler's own event log).
- `zero-downtime.log` - 240/240 requests returned 200 during a backend rollout
  (`maxUnavailable: 0`), zero dropped.
- `pvc-persist.log` - rows written to Postgres survive deleting `postgres-0`; the
  recreated pod reattaches the same PVC and the data is still there.
- `failover.log` - draining a worker reschedules its pods onto the other nodes
  (PDB keeps one up) and the app keeps returning 200.
- `argocd-synced.log` - Argo CD owns the app and reports Synced + Healthy,
  reconciling `manifests/overlays/prod` from the fork (no manual apply in the
  final state).

Produced without a cluster:

- `rendered-manifests.yaml` - full `kubectl kustomize manifests/overlays/prod`.
- `terraform-validate.log` - `terraform validate` passes.

Not capturable locally:

- A valid Let's Encrypt cert on the real domain needs a publicly reachable
  ingress for the HTTP-01 challenge, which a local cluster behind NAT cannot
  provide. The cert-manager ClusterIssuer + Ingress TLS config is in the repo and
  issues a real cert when run on the cloud path with DNS pointed at the node.
