# Cost

Approximate on-demand list prices in eu-north-1 (Stockholm). Rounded; the real
bill depends on usage and any free-tier credits.

## Monthly cost

| Item | Spec | Qty | $/mo |
|---|---|---:|---:|
| control-plane VM | t2.medium (2 vCPU / 4 GiB) | 1 | ~33 |
| worker VMs | t2.small (1 vCPU / 2 GiB) | 2 | ~34 |
| block storage (root) | 20 GiB gp3 at ~$0.08/GiB | 3 | ~5 |
| Elastic IP | attached to a running instance | 1 | 0 |
| load balancer | none (ingress on hostPort) | 0 | 0 |
| state storage | S3 + DynamoDB (on-demand) | 1 | <1 |
| data transfer out | light demo traffic | - | ~1-3 |
| DNS / domain | ~$12/yr amortized | 1 | ~1 |
| **Total** | | | **~$73/mo** |

That figure is the 24/7 monthly rate. In practice EC2 and EBS bill by the hour
(about $0.12/hr for all three nodes), and the cluster only runs while building
and demoing, so a few days of work costs a few dollars before `make destroy`.

## Compared to the single-server Compose + Portainer deploy

The old single-VM stack was about $18/mo. The cluster is about $73/mo, roughly
4x. The extra spend buys multi-node scheduling, self-healing across nodes,
zero-downtime deploys, autoscaling, and GitOps reconciliation. For a low-traffic
internal tool with a tolerable maintenance window the single box is cheaper and
simpler and that machinery is wasted; the cluster is worth it once you actually
need the availability and scale.

## How I'd halve it

The biggest lever is spot workers: t2.small spot in eu-north-1 runs about 60-70%
cheaper, dropping the two workers from ~$34 to ~$11. Shrinking the control-plane
to t2.small (Argo CD fits in 2 GiB if you trim its replicas) saves another ~$16,
landing near $35/mo while keeping all three nodes. Going further (two nodes, or
the cheapest burstable instances) gives up the headroom that keeps the
node-failover demo clean, so I'd stop at spot workers plus a smaller server.

A different provider changes the maths: three small VMs on Hetzner are roughly
EUR 15/mo. I used AWS to match the existing infra and the S3/DynamoDB
remote-state requirement.
