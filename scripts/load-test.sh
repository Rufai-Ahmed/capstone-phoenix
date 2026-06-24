#!/usr/bin/env bash
# Drive load to trigger the backend HPA. Watch it scale in another terminal:
#   kubectl -n taskapp get hpa backend -w
#   ./scripts/load-test.sh https://taskapp.<you>.com [seconds] [concurrency]
set -euo pipefail
URL="${1:?usage: load-test.sh https://taskapp.<you>.com [seconds] [concurrency]}"
DUR="${2:-180}"; CONC="${3:-50}"
TARGET="$URL/api/health"

if command -v hey >/dev/null; then
  hey -z "${DUR}s" -c "$CONC" "$TARGET"
elif command -v ab >/dev/null; then
  ab -t "$DUR" -c "$CONC" "$TARGET"
else
  echo "Install 'hey' (brew install hey) or 'ab'. Fallback — in-cluster load:"
  echo "  kubectl -n taskapp run loadgen --image=busybox --restart=Never -- \\"
  echo "    /bin/sh -c 'while true; do wget -q -O- http://backend:5000/api/health >/dev/null; done'"
  exit 1
fi
