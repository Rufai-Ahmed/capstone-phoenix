#!/usr/bin/env bash
# 3 Ubuntu VMs via Multipass = a real multi-node cluster, for capturing evidence
# when no cloud account is available. Same Ansible roles + manifests as the AWS path.
set -euo pipefail
cd "$(dirname "$0")/../.."

KEY="${HOME}/.ssh/capstone-phoenix"
[ -f "${KEY}.pub" ] || ssh-keygen -t ed25519 -f "$KEY" -N "" -C capstone-phoenix

CI="$(mktemp)"
cat > "$CI" <<EOF
#cloud-config
ssh_authorized_keys:
  - $(cat "${KEY}.pub")
EOF

launch() {
  if multipass info "$1" >/dev/null 2>&1; then multipass start "$1" || true
  else multipass launch 22.04 --name "$1" --cpus "$2" --memory "$3" --disk "$4" --cloud-init "$CI"; fi
}
launch control-plane             2 1536M 5G
launch capstone-phoenix-worker-1 1 1G 4G
launch capstone-phoenix-worker-2 1 1G 4G
rm -f "$CI"

for n in control-plane capstone-phoenix-worker-1 capstone-phoenix-worker-2; do
  multipass exec "$n" -- cloud-init status --wait >/dev/null 2>&1 || true
done

ipof() { multipass info "$1" --format json | python3 -c "import sys,json;print(json.load(sys.stdin)['info']['$1']['ipv4'][0])"; }
SIP="$(ipof control-plane)"
W1="$(ipof capstone-phoenix-worker-1)"
W2="$(ipof capstone-phoenix-worker-2)"

cat > infra/ansible/inventory/hosts.ini <<EOF
[server]
control-plane ansible_host=${SIP}

[agents]
capstone-phoenix-worker-1 ansible_host=${W1}
capstone-phoenix-worker-2 ansible_host=${W2}

[k3s_cluster:children]
server
agents

[k3s_cluster:vars]
server_private_ip=${SIP}
server_public_ip=${SIP}
EOF

echo "VMs up: control-plane=${SIP} worker-1=${W1} worker-2=${W2}"
echo "inventory -> infra/ansible/inventory/hosts.ini"
