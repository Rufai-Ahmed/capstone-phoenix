# Cost

Approximate on-demand list prices in eu-north-1 (Stockholm). Rounded; the real
bill depends on usage and any free-tier credits.

## Monthly cost

| Item | Spec | Qty | $/mo |
|---|---|---:|---:|
| control-plane VM | t3.medium (2 vCPU / 4 GiB) | 1 | ~33 |
| worker VMs | t3.small (2 vCPU / 2 GiB) | 2 | ~33 |
| block storage (root) | 20 GiB gp3 at ~$0.08/GiB | 3 | ~5 |
| public IPv4 | 1 EIP + 2 auto-assigned, ~$3.60/mo each | 3 | ~11 |
| load balancer | none (ingress on hostPort) | 0 | 0 |
| state storage | S3 + DynamoDB (on-demand) | 1 | <1 |
| data transfer out | light demo traffic | - | ~1-3 |
| DNS / domain | ~$12/yr amortized | 1 | ~1 |
| **Total** | | | **~$84/mo** |

That figure is the 24/7 monthly rate. In practice EC2 and EBS bill by the hour
(about $0.12/hr for all three nodes), and the cluster only runs while building
and demoing, so a few days of work costs a few dollars before `make destroy`.

## Compared to the single-server Compose + Portainer deploy

The old single-VM stack was about $18/mo. The cluster is about $84/mo, nearly
5x. The extra spend buys multi-node scheduling, self-healing across nodes,
zero-downtime deploys, autoscaling, and GitOps reconciliation. For a low-traffic
internal tool with a tolerable maintenance window the single box is cheaper and
simpler and that machinery is wasted; the cluster is worth it once you actually
need the availability and scale.

## How I'd halve it

The biggest lever is spot workers: t3.small spot in eu-north-1 runs about 60-70%
cheaper, dropping the two workers from ~$33 to ~$11. Shrinking the control-plane
to t3.small (Argo CD fits in 2 GiB if you trim its replicas) and dropping the
workers' public IPs takes the total to near $40/mo, about half, while keeping all
three nodes. Going further (two nodes, or
the cheapest burstable instances) gives up the headroom that keeps the
node-failover demo clean, so I'd stop at spot workers plus a smaller server.

A different provider changes the maths: three small VMs on Hetzner are roughly
EUR 15/mo. I used AWS to match the existing infra and the S3/DynamoDB
remote-state requirement.
