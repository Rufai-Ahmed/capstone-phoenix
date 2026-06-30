# infra/local - free local cluster for evidence

A zero-cost way to run the cluster and capture evidence when no cloud account is
available (here: a new AWS account whose vCPU quota increase was declined). The
Ansible roles, manifests, and GitOps config are the same as the cloud path; only
where the nodes run changes.

Two options:

- `k3d-up.sh` / `k3d-down.sh` - k3d (k3s in Docker). Nodes are containers, light
  and reliable. This is what produced the logs in `docs/EVIDENCE/`.
- `up.sh` / `down.sh` - 3 Ubuntu VMs via Multipass (closer to real separate
  machines). Its QEMU backend crashes on some Intel Macs, which is why the
  evidence here was captured with k3d instead.

```bash
./infra/local/k3d-up.sh                 # 3-node cluster + the app
# ... capture evidence ...
./infra/local/k3d-down.sh               # tear down
```

The real separate-machine, public-HTTPS run is the AWS path in `docs/RUNBOOK.md`.
