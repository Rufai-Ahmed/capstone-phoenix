# Cost

Approximate **on-demand list prices, `eu-north-1` (Stockholm)**. Round numbers;
your bill varies with usage and any free-tier credits.

## Monthly itemized cost

| Item | Spec | Qty | $/mo |
|---|---|---:|---:|
| control-plane VM | `t3.medium` (2 vCPU / 4 GiB) | 1 | ~33 |
| worker VMs | `t3.small` (2 vCPU / 2 GiB) | 2 | ~33 |
| block storage (root) | 20 GiB gp3 @ ~$0.08/GiB | 3 | ~5 |
| Elastic IP | attached to a running instance | 1 | 0 |
| load balancer | none (ingress via hostPort) | 0 | 0 |
| object storage + lock | S3 state + DynamoDB (on-demand) | 1 | <1 |
| data transfer out | light demo traffic | — | ~1–3 |
| DNS / domain | ~$12/yr amortized | 1 | ~1 |
| **Total** | | | **≈ $73/mo** |

## Compared to the single-server Compose + Portainer deploy

- That stack: one small VM (~`t3.small`) + a volume + a domain ≈ **$18/mo**.
- This cluster: ≈ **$73/mo** — roughly **4×**.
- **What the extra ~$55 buys:** real multi-node scheduling, self-healing across
  nodes, zero-downtime rolling deploys, autoscaling under load, and GitOps
  reconciliation. **When it's NOT worth it:** a low-traffic internal tool with a
  tolerable maintenance window — the single box is cheaper and simpler, and the
  HA/autoscale machinery is overhead you pay for and don't use. The capstone's
  point is to *be able to* justify the jump, not to claim it's always right.

## How I'd halve this

Spot/preemptible workers are the biggest lever: `t3.small` spot in `eu-north-1`
runs ~60–70% cheaper, dropping the two workers from ~$33 to ~$11. Combined with
shrinking the control-plane to `t3.small` (Argo CD fits in 2 GiB if you trim its
component replicas) for another ~$16 saved, the total lands near **$35/mo** —
about half — while keeping all three nodes. Going further (a 2-node cluster, or
k3s on the cheapest burstable instances) trades away the headroom that makes the
node-failover demo clean, so I'd stop at spot workers + a smaller server.

> Footnote: a different provider changes the maths entirely — equivalent 3× small
> VMs on Hetzner are roughly €15/mo total. AWS is used here to match the team's
> existing infra and the S3/DynamoDB remote-state requirement.
