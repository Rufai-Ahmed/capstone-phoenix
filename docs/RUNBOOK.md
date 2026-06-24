# Runbook

Clone -> live HTTPS multi-node GitOps TaskApp. Every command is exact.

## 0. Prerequisites (your machine)

- `terraform >= 1.5`, `ansible`, `kubectl`, `git`, and an AWS account with creds
  exported (`aws configure` / `AWS_PROFILE`).
- `kubeseal` (only if you use Sealed Secrets), `hey` (only for the load test).
- A domain you control (to create a DNS A record).
- An SSH keypair for the nodes:
  ```bash
  ssh-keygen -t ed25519 -f ~/.ssh/capstone-phoenix -C capstone-phoenix
  ```
- Fork this repo, then tell the GitOps layer about your fork:
  ```bash
  ./scripts/set-repo-url.sh https://github.com/<you>/capstone-phoenix.git
  git commit -am "point gitops at my fork" && git push
  ```

## 1. Provision from zero

```bash
# 1a. Remote state (once per account)
make bootstrap

# 1b. Nodes. Copy the example tfvars and set YOUR ip + key path first.
cp infra/terraform/terraform.tfvars.example infra/terraform/terraform.tfvars
#   edit: ssh_allowed_cidr = "$(curl -s ifconfig.me)/32"
make infra            # prints server EIP, worker IPs; writes the Ansible inventory

# 1c. k3s across the nodes + a local kubeconfig
make cluster          # -> infra/ansible/kubeconfig
make nodes            # control-plane + 2 workers = Ready
```

## 2. DNS

Point your domain at the server's Elastic IP (from `terraform output dns_target`):

```
taskapp.<you>.com.   A   <server-eip>
```

Then set the domain in 3 spots (overlay) and the ACME email (issuer):

- `manifests/overlays/prod/kustomization.yaml` — replace `taskapp.example.com` (×3)
- `platform/cluster-issuer.yaml` — replace `you@example.com` (×2)

```bash
git commit -am "set domain + acme email" && git push
```

## 3. The Secret (pick one, before the app syncs)

**A — out-of-band (simplest):**
```bash
kubectl create namespace taskapp --dry-run=client -o yaml | kubectl apply -f -
kubectl -n taskapp create secret generic taskapp-secret \
  --from-literal=DATABASE_PASSWORD="$(openssl rand -base64 24)" \
  --from-literal=SECRET_KEY="$(python3 -c 'import secrets;print(secrets.token_hex(32))')"
```

**B — Sealed Secrets (git owns it):** do this *after* step 4 installs the
controller, then:
```bash
./scripts/seal-secret.sh                 # writes manifests/base/taskapp.sealed.yaml
# uncomment '- taskapp.sealed.yaml' in manifests/base/kustomization.yaml
git commit -am "sealed db secret" && git push
```

## 4. GitOps takes over

```bash
make argocd           # install Argo CD
make gitops           # apply the app-of-apps; Argo installs everything else
```

Argo now reconciles, in wave order: sealed-secrets -> cert-manager ->
ingress-nginx -> cluster-issuer -> taskapp. Watch it:

```bash
kubectl -n argocd get applications -w
# password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
# UI:       kubectl -n argocd port-forward svc/argocd-server 8080:443
```

## 5. Verify

```bash
make nodes                                   # 3 Ready
kubectl -n taskapp get pods -o wide          # 2 frontend + 2 backend on different nodes, postgres-0
kubectl -n taskapp get certificate           # taskapp-tls = Ready=True
curl -sI https://taskapp.<you>.com | head -1 # HTTP/2 200
./scripts/collect-evidence.sh                # snapshots -> docs/EVIDENCE
```

> First cert issuance can take 1–2 min. If it stalls, use `letsencrypt-staging`
> (swap the annotation on the Ingress) to dodge prod rate limits while debugging.

---

## Day-2 operations

- **Scale a tier (frontend):** edit `replicas` in
  `manifests/base/frontend-deployment.yaml`, commit, push. Argo applies it — no
  `kubectl apply`. (Backend scales itself via the HPA.)
- **Roll back a bad deploy:** `git revert` the image bump in
  `manifests/overlays/prod/kustomization.yaml` and push; or in the Argo UI,
  History -> Rollback to a previous Synced revision.
- **Ship a new image:** `cd manifests/overlays/prod && kustomize edit set image
  ghcr.io/ts-a-devops/taskapp-backend=ghcr.io/ts-a-devops/taskapp-backend:<sha>`,
  commit, push. The migration Job re-runs (Replace=true), then backend rolls.
- **Run a new migration safely:** it rides the image bump above — the Job applies
  `alembic upgrade head` before the new backend pods start.
- **Rotate a secret:** re-run `./scripts/seal-secret.sh` with new values, push
  (or recreate the out-of-band Secret), then
  `kubectl -n taskapp rollout restart deploy/backend statefulset/postgres`.

## Failure recovery

- **Worker node dies / is drained (the live-demo):**
  ```bash
  kubectl drain capstone-phoenix-worker-1 --ignore-daemonsets --delete-emptydir-data
  ```
  Its frontend/backend pods reschedule onto the other nodes; PDBs keep ≥1 up;
  the site stays 200 (prove it with `./scripts/zero-downtime-check.sh`).
  Recover: `kubectl uncordon capstone-phoenix-worker-1`. (Keep `postgres-0`'s
  node out of the drain — its `local-path` data lives there; see ARCHITECTURE §5.)
- **Backend pod crashloops:** `kubectl -n taskapp logs <pod> --previous`,
  `kubectl -n taskapp describe pod <pod>`, `kubectl -n taskapp get events
  --sort-by=.lastTimestamp`. Usual cause: wrong/missing `taskapp-secret`.
- **Bad migration:** revert the image bump (above) so the previous schema/code
  redeploys; restore Postgres from backup if the migration was destructive.
- **Postgres pod rescheduled (PVC re-attaches):**
  ```bash
  kubectl -n taskapp exec postgres-0 -- psql -U taskapp_user -d taskapp -c "create table t(x int); insert into t values(1);"
  kubectl -n taskapp delete pod postgres-0
  kubectl -n taskapp wait --for=condition=ready pod/postgres-0 --timeout=120s
  kubectl -n taskapp exec postgres-0 -- psql -U taskapp_user -d taskapp -c "select * from t;"  # row still there
  ```
