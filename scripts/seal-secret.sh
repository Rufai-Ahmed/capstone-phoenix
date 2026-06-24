#!/usr/bin/env bash
# Seal the app Secret so the ENCRYPTED form can live in git (Argo owns it).
# Needs: kubeseal + the sealed-secrets controller running (gitops/apps/sealed-secrets).
#   DATABASE_PASSWORD=... SECRET_KEY=... ./scripts/seal-secret.sh
# Unset vars are generated for you.
set -euo pipefail

DB_PW="${DATABASE_PASSWORD:-$(openssl rand -base64 24)}"
APP_KEY="${SECRET_KEY:-$(python3 -c 'import secrets;print(secrets.token_hex(32))')}"
OUT="manifests/base/taskapp.sealed.yaml"

kubectl create secret generic taskapp-secret \
  --namespace taskapp \
  --from-literal=DATABASE_PASSWORD="$DB_PW" \
  --from-literal=SECRET_KEY="$APP_KEY" \
  --dry-run=client -o yaml |
  kubeseal \
    --controller-namespace sealed-secrets \
    --controller-name sealed-secrets \
    --format yaml > "$OUT"

echo "Wrote $OUT (safe to commit)."
echo "Now uncomment '- taskapp.sealed.yaml' in manifests/base/kustomization.yaml, commit, push."
