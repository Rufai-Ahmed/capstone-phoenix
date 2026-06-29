#!/usr/bin/env bash
# Point the Argo CD apps at YOUR fork.
#   ./scripts/set-repo-url.sh https://github.com/<you>/capstone-phoenix.git
set -euo pipefail
REPO="${1:?usage: set-repo-url.sh https://github.com/<you>/capstone-phoenix.git}"
for f in gitops/root-app.yaml gitops/apps/taskapp.yaml gitops/apps/cluster-issuer.yaml; do
  sed -i.bak -E "s#(repoURL: ).*/capstone-phoenix\.git#\1${REPO}#" "$f" && rm -f "$f.bak"
  echo "updated $f"
done
echo "repoURL now: $REPO"
