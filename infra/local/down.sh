#!/usr/bin/env bash
# Delete the local VMs and reclaim RAM/disk.
set -euo pipefail
for n in control-plane capstone-phoenix-worker-1 capstone-phoenix-worker-2; do
  multipass delete "$n" 2>/dev/null || true
done
multipass purge
echo "local cluster removed."
