#!/usr/bin/env bash
# Snapshot the cluster state into docs/EVIDENCE/*.log. Pair with screenshots.
set -euo pipefail
OUT="docs/EVIDENCE"; mkdir -p "$OUT"
run() { echo "+ $*"; "$@" 2>&1; echo; }

{
  run kubectl get nodes -o wide
} | tee "$OUT/nodes-ready.log"

{
  run kubectl -n taskapp get pods -o wide
} | tee "$OUT/pods-spread.log"

{
  run kubectl -n taskapp get hpa backend
  run kubectl -n taskapp get pdb
} | tee "$OUT/hpa-pdb.log"

{
  run kubectl -n taskapp get pvc
  run kubectl get pv
} | tee "$OUT/pvc.log"

{
  run kubectl -n argocd get applications
} | tee "$OUT/argocd-apps.log"

{
  run kubectl -n taskapp get ingress
  run kubectl -n taskapp get certificate
} | tee "$OUT/tls.log"

echo "Wrote logs to $OUT/. Add screenshots (argocd UI, SSL Labs, HPA climbing) next to them."
