#!/usr/bin/env bash
# Poll the site while you roll a deploy in another terminal. fail should stay 0.
#   ./scripts/zero-downtime-check.sh https://taskapp.<you>.com | tee docs/EVIDENCE/zero-downtime.log
#   (other terminal) kubectl -n taskapp rollout restart deploy/frontend
set -euo pipefail
URL="${1:?usage: zero-downtime-check.sh https://taskapp.<you>.com}"
PATH_="${2:-/healthz}"
ok=0; fail=0
trap 'echo; echo "TOTAL ok=$ok fail=$fail"; exit 0' INT
echo "Polling $URL$PATH_ — Ctrl-C to stop."
while true; do
  code=$(curl -ks -o /dev/null -w '%{http_code}' "$URL$PATH_" || echo 000)
  if [ "$code" = "200" ]; then ok=$((ok+1)); else fail=$((fail+1)); echo "$(date +%T) -> $code"; fi
  printf '\rok=%d fail=%d ' "$ok" "$fail"
  sleep 0.3
done
