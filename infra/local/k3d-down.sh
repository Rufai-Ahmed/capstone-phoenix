#!/usr/bin/env bash
set -euo pipefail
k3d cluster delete capstone
echo "k3d cluster removed."
