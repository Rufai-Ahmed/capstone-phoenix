#!/usr/bin/env bash
# Free local 3-node cluster for capturing evidence, using k3d (k3s in Docker).
# Needs Docker running. The nodes are containers, not VMs, but the scheduling,
# autoscaling, rollout and failover behaviour is genuine. Multipass VMs are the
# alternative (see up.sh), but its QEMU backend crashes on some Intel Macs.
set -euo pipefail
cd "$(dirname "$0")/../.."

k3d cluster create capstone --servers 1 --agents 2 --wait

kubectl create namespace taskapp --dry-run=client -o yaml | kubectl apply -f -
kubectl -n taskapp create secret generic taskapp-secret \
  --from-literal=DATABASE_PASSWORD="$(openssl rand -base64 24)" \
  --from-literal=SECRET_KEY="$(python3 -c 'import secrets;print(secrets.token_hex(32))')"

kubectl apply -k manifests/overlays/prod
kubectl -n taskapp rollout status statefulset/postgres --timeout=300s
kubectl -n taskapp rollout status deploy/backend --timeout=300s
kubectl -n taskapp rollout status deploy/frontend --timeout=180s
kubectl get nodes -o wide
