#!/usr/bin/env bash
# Point the Argo CD apps at YOUR fork.
#   ./scripts/set-repo-url.sh https://github.com/<you>/capstone-phoenix.git
set -euo pipefail
REPO="${1:?usage: set-repo-url.sh https://github.com/<you>/capstone-phoenix.git}"
PLACEHOLDER="https://github.com/REPLACE_ME/capstone-phoenix.git"
grep -rl "$PLACEHOLDER" gitops | while read -r f; do
  sed -i.bak "s#${PLACEHOLDER}#${REPO}#g" "$f" && rm -f "$f.bak"
  echo "updated $f"
done
echo "Done. repoURL now: $REPO"
