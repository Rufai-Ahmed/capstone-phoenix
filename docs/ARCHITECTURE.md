# Architecture

## 1. Topology

3 EC2 nodes in one AWS VPC (eu-north-1) running k3s. The control-plane node is
left schedulable so all 3 nodes run workloads. ingress-nginx runs as a DaemonSet
on host ports 80/443, and DNS points at the control-plane's Elastic IP.

```
                Internet
                   |   taskapp.<you>.com  (A record -> server EIP)
                   v
          +-------------------------------+
   :80/443| ingress-nginx (DaemonSet)     |  TLS via cert-manager + Let's Encrypt
          +-------------------------------+
                   |  Ingress -> frontend:80
                   v
            Service/frontend (ClusterIP)
              |                     |
              v                     v
        frontend pod          frontend pod     nginx serves the SPA, proxies /api -> backend
              |                     |
              +----------+----------+
                         v
                Service/backend:5000
              |                     |
              v                     v
         backend pod           backend pod     gunicorn, autoscaled by the HPA (2..6)
              |                     |
              +----------+----------+
                         v
            Service/postgres (headless)
                         v
              postgres-0  (StatefulSet + PVC on local-path)

nodes: control-plane (k3s server) + worker-1, worker-2 (k3s agents)
platform (managed by Argo CD): argocd, ingress-nginx, cert-manager, sealed-secrets
(metrics-server is built into k3s)
```

## 2. Node and network

- Nodes: 1x t3.medium control-plane (runs the API server and Argo CD) and 2x
  t3.small workers. Ubuntu 22.04, spread across 2 AZs (eu-north-1a/b).
- Network: one VPC 10.20.0.0/16 with two public subnets (10.20.1.0/24 and
  10.20.2.0/24). Nodes have public IPs and reach the internet through the
  Internet Gateway. I did not add a NAT gateway because it costs ~$32/mo and
  buys nothing here.
- Firewall (the AWS security group does the enforcing):
  - 22: my IP only.
  - 80, 443: open to the world for ingress.
  - everything else (k3s API 6443, flannel VXLAN 8472/udp, kubelet 10250,
    NodePorts): intra-VPC only. 6443 is never exposed to the internet.
- A host UFW role is included but off by default. The security group already
  enforces least privilege, and UFW's default FORWARD policy is DROP, which
  quietly breaks pod networking. When enabled it sets DEFAULT_FORWARD_POLICY to
  ACCEPT and allows the VPC, pod and service CIDRs.

## 3. Request flow

DNS resolves taskapp.<you>.com to the server's EIP. The request hits
ingress-nginx on that node's host port 443, where cert-manager has already put a
Let's Encrypt cert (HTTP-01) into the taskapp-tls Secret, so TLS terminates
there. The Ingress sends the host to Service/frontend:80. nginx in the frontend
pod serves the React SPA and reverse-proxies /api/ to http://backend:5000 (the
backend Service, resolved by cluster DNS). gunicorn handles the request and talks
to Postgres at postgres:5432 through the headless Service. Responses go back up
the same path.

## 4. Single-server assumptions I had to fix

| Assumption that was fine on one box | Why it breaks on a cluster | Fix |
|---|---|---|
| migrate-on-boot in the entrypoint | 2+ replicas race on `alembic upgrade head` | Deployment overrides `command:` to run gunicorn directly (skipping the migrating entrypoint); migrations run once as a Job (sync-wave 2, after the DB, before the backend; Replace=true re-runs it on an image bump) |
| named volume on the host | a rescheduled pod loses its data on another box | Postgres is a StatefulSet with a PVC on local-path; the PV's node affinity makes postgres-0 reattach to its data (pod kills are safe, node loss is the documented limit, see section 5) |
| ports published on the host | many pods on many nodes need one front door | ingress-nginx DaemonSet plus one Ingress; Services give stable virtual IPs in front of the pods |
| container up = ready | traffic hits a pod before its DB is reachable | startup/readiness/liveness probes; readiness gates the Service endpoints. Backend readiness uses the DB-aware /api/health, liveness is a cheap TCP check so a DB blip does not restart the pod |
| restart the box to recover | one box is a single point of failure | self-healing: failed pods reschedule, 2+ replicas with topology spread, PDBs keep at least one pod up during drains |
| compose redeploy has a short outage | users see 502s during a deploy | rolling update with maxUnavailable 0 and maxSurge 1, readiness gating, and a preStop drain so no requests are dropped |
| secrets in a .env on the box | not in version control, or committed in plaintext | secrets are not in the manifests: created out-of-band on first run, then sealed so only the encrypted form goes in git |
| one box handles all load | cannot absorb spikes | HPA scales the backend 2 to 6 on CPU (k3s ships metrics-server) |
| flat network, everything talks to everything | a compromised pod can reach the DB | NetworkPolicy default-deny plus segmented rules (ingress to frontend to backend to postgres only) |

## 5. Choices and trade-offs

- kustomize (plain YAML base + prod overlay) instead of Helm. The objects stay
  readable, and the overlay is the one place I pin image tags
  (`kustomize edit set image`) and set the domain. Argo renders kustomize
  natively, so Helm would just add templating I don't need for one app.
- ingress-nginx instead of k3s's bundled Traefik. It is the most documented
  controller and works cleanly with cert-manager. I run it as a DaemonSet with
  hostPort (no cloud load balancer), so DNS can point at any node and draining a
  worker never removes the ingress path. The trade-off is that one DNS A record
  points at one node; the HA version of this is an AWS NLB across all nodes.
- NetworkPolicy: k3s uses flannel plus an embedded kube-router that actually
  enforces NetworkPolicy, so the default-deny rules do real work.
- Storage: k3s local-path. It needs no setup and is fine for a single Postgres.
  The PV is node-local, so pod kills reattach and data survives. The limit is
  that if the node holding postgres-0 dies, the data is stranded. Surviving node
  loss would need Longhorn or the AWS EBS CSI driver; I left that as an upgrade
  to keep the cluster dependency-free.
- Secrets: sealed-secrets as the main path, with out-of-band creation for the
  first run. Committing a plaintext Secret would defeat the purpose, so the
  sealed-secrets controller lets the encrypted SealedSecret live in git and be
  reconciled by Argo. No plaintext secret is ever committed.
- Single control-plane, not HA. The brief says the difficulty is in Kubernetes,
  not the control plane, so one k3s server is enough. etcd HA (3 servers) is a
  separate upgrade.
- The frontend securityContext is lighter than the backend's. The given nginx
  image binds port 80 as root and writes its own pid/cache, so it cannot be
  runAsNonRoot or readOnlyRootFilesystem without rebuilding the image (the brief
  says not to). It still drops all caps except the ones nginx needs, blocks
  privilege escalation, and uses the default seccomp profile. The backend,
  Postgres and the migration Job all run fully non-root with seccomp and caps
  dropped.
