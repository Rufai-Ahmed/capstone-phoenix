# Architecture

## 1. Topology

3 EC2 nodes in one AWS VPC (`eu-north-1`), k3s. The control-plane node is left
schedulable, so all 3 nodes run workloads. ingress-nginx runs as a DaemonSet
binding host ports 80/443 on every node; DNS points at the control-plane's
Elastic IP.

```
                          Internet
                             │  taskapp.<you>.com  (A -> server EIP)
                             ▼
                   :80/:443  ┌───────────────────────────────────────────┐
                   (hostPort)│            ingress-nginx (DaemonSet)        │  TLS by cert-manager
                             └───────────────────────────────────────────┘  (Let's Encrypt, HTTP-01)
                                                │  Ingress: taskapp -> frontend:80
                                                ▼
                                      Service/frontend (ClusterIP)
                              ┌──────────────────┴───────────────────┐
                              ▼                                       ▼
                       frontend pod (node A)                  frontend pod (node B)
                       nginx: SPA + proxy /api/ ─────────────────────┐
                                                                     ▼
                                                          Service/backend :5000
                                            ┌──────────────────┴──────────────────┐
                                            ▼                                      ▼
                                     backend pod (node B)                  backend pod (node C)   ◀── HPA 2..6
                                     gunicorn :5000                                │
                                            └──────────────┬───────────────────────┘
                                                           ▼
                                              Service/postgres (headless)
                                                           ▼
                                              postgres-0  (StatefulSet, node C)
                                                           │
                                              PVC (local-path) ── EBS gp3 on node C

  nodes: A = capstone-phoenix-server (k3s server)   B,C = capstone-phoenix-worker-{1,2} (k3s agents)
  platform (Argo-managed): argocd, ingress-nginx, cert-manager, sealed-secrets, metrics-server (k3s built-in)
```

## 2. Node & network

- **Nodes:** 1× `t3.medium` control-plane (runs the API + Argo CD), 2× `t3.small`
  workers. Ubuntu 22.04. Spread across 2 AZs (`eu-north-1a/b`).
- **Network:** one VPC `10.20.0.0/16`, two public subnets (`10.20.1.0/24`,
  `10.20.2.0/24`). Nodes have public IPs and egress via the Internet Gateway —
  **no NAT gateway** (it would add ~$32/mo for no benefit here; see COST).
- **Firewall (the AWS security group is the enforcing firewall):**
  - `22` — operator IP only.
  - `80`, `443` — world (ingress).
  - everything else (k3s API `6443`, flannel VXLAN `8472/udp`, kubelet `10250`,
    NodePorts) — **intra-VPC only**. `6443` is never exposed to the internet.
- Host UFW is shipped but **off by default**: the SG already enforces least
  privilege, and UFW's default `FORWARD` DROP silently breaks CNI traffic. If
  enabled, the role sets `DEFAULT_FORWARD_POLICY=ACCEPT` and allows the VPC/pod/
  service CIDRs.

## 3. Request flow

DNS resolves `taskapp.<you>.com` to the server's EIP. The packet hits
ingress-nginx on that node's host port `443`; cert-manager has provisioned a
Let's Encrypt cert (HTTP-01) into the `taskapp-tls` Secret, so TLS terminates
there. The Ingress routes the host to `Service/frontend:80`. nginx in the
frontend pod serves the React SPA and reverse-proxies `/api/` to
`http://backend:5000` (resolved via cluster DNS to `Service/backend`). gunicorn
handles the request and talks to Postgres at `postgres:5432` (the headless
Service -> `postgres-0`). Responses return back up the same path.

## 4. Single-server assumptions fixed

| Single-server assumption | Why it breaks at scale | How it's fixed here |
|---|---|---|
| migrate-on-boot in the entrypoint | 2+ replicas race on `alembic upgrade head` | Deployment overrides `command:` to start gunicorn directly (skips the migrating entrypoint); migrations run once as a **Job** (sync-wave 2, after DB, before backend; `Replace=true` re-runs on image bump). |
| named volume on the host | a rescheduled pod loses its data on another box | Postgres is a **StatefulSet** with a **PVC** (`local-path`). The PV carries node affinity so `postgres-0` always reattaches to its data. (Survives pod kills; node loss is the documented limit — see §5.) |
| `ports:` published on the host | many pods on many nodes need one front door | **ingress-nginx** DaemonSet + a single **Ingress**; Services give stable virtual IPs in front of pod sets. |
| "the container is up = it's ready" | traffic hits a pod before its DB is reachable | **startup/readiness/liveness probes**; readiness gates Service endpoints. Backend readiness uses DB-aware `/api/health`; liveness is a cheap TCP check to avoid restart storms. |
| restart the box to recover | one box = a single point of failure | k8s self-healing: failed pods reschedule; **2+ replicas** with topology spread; **PDBs** keep ≥1 up during drains. |
| `docker compose up -d` redeploy = brief downtime | users see 502s during a deploy | rolling update with **`maxUnavailable: 0`** + `maxSurge: 1`, readiness gating, and a `preStop` drain delay -> zero dropped requests. |
| secrets in a `.env` on the box | not in source control, or worse, committed plaintext | secrets are **not** in the manifests: created out-of-band for first run, then **Sealed Secrets** so only the *encrypted* form lives in git. |
| one box handles all load | can't absorb spikes | **HPA** scales the backend 2->6 on CPU (k3s ships metrics-server). |
| flat network, everything talks to everything | a compromised pod can reach the DB | **NetworkPolicy** default-deny + segmented (ingress->frontend->backend->postgres only). |

## 5. Choices & trade-offs

- **kustomize (raw YAML base + prod overlay)**, not Helm. The objects are
  readable as-is; the overlay is the single place to pin image tags
  (`kustomize edit set image`) and set the domain. Argo renders kustomize
  natively. Helm would add templating indirection we don't need for one app.
- **ingress-nginx over k3s's bundled Traefik.** It's the most widely documented
  controller and pairs cleanly with cert-manager. We `--disable traefik` and run
  ingress-nginx as a **DaemonSet with hostPort** (no cloud LB): DNS can point at
  any node, and draining a worker never removes the ingress path. The trade-off
  is a single DNS A record (the server EIP) = one edge node; the HA upgrade is an
  AWS NLB across all nodes (added cost, noted in COST).
- **CNI / NetworkPolicy:** k3s's default flannel plus its embedded kube-router
  **enforces** NetworkPolicy, so the default-deny policies are real, not cosmetic.
- **Storage: k3s `local-path`.** Zero setup and fine for a single Postgres: the
  PV is node-local, so pod kills reattach and data persists. The honest limit:
  if the *node* hosting `postgres-0` dies, the data is stranded. Surviving node
  loss needs replicated/network storage — **Longhorn** (k3s-native, replicates
  across nodes) or the **AWS EBS CSI driver** (re-attach within an AZ). Left as a
  documented upgrade to keep the cluster setup dependency-free.
- **Secrets: Sealed Secrets (primary) + out-of-band (bootstrap).** Committing a
  plaintext Secret to "let git own everything" defeats the point. The
  sealed-secrets controller lets the *encrypted* SealedSecret live in git and be
  reconciled by Argo. First run can also just `kubectl create secret` and let
  Argo ignore it. Either way no plaintext secret is ever committed.
- **Single control-plane (not HA).** Per the brief, cluster difficulty lives in
  Kubernetes, not the control plane. One k3s server is the right cost/complexity
  point; etcd-HA (3 servers) is a known, separate upgrade.
- **Frontend securityContext is lighter than the backend's.** The given nginx
  image binds `:80` as root and writes its pid/cache, so it can't be
  `runAsNonRoot` / `readOnlyRootFilesystem` without rebuilding it (the brief says
  don't). We still drop all caps except those nginx needs, block privilege
  escalation, and apply the default seccomp profile. Backend, Postgres, and the
  migration Job run fully non-root + seccomp + caps-dropped.
