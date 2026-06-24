# Architecture Decisions

This project intentionally deviates from a "textbook" AWS enterprise
setup in a few places. Each deviation below is a deliberate cost or
security decision, not a shortcut taken out of ignorance - documented
here so the reasoning is explainable in an interview or review.

## 1. Self-managed Kubernetes (kubeadm on EC2) instead of Amazon EKS

**Original ask:** Provision an EKS cluster with managed node groups.

**Decision:** A single EC2 instance, bootstrapped with `kubeadm` via
Terraform `user_data` (see `terraform/ec2.tf` and
`terraform/scripts/bootstrap-k8s.sh`), acting as both control-plane and
worker node.

**Why:** The EKS control plane costs $0.10/hour (~$73/month) with no
free tier, running continuously even when idle - incompatible with a
near-zero budget. A single EC2 instance that we explicitly start/stop
per session costs a few dollars total across the whole project instead.
The trade-off: no control-plane HA, no managed upgrades, and the
cluster only exists while the instance is running - all acceptable for
a learning project, not for real production traffic.

This also turned out to make two *later* phases more authentic rather
than less: Phase 5's CloudWatch CPU/memory metrics and Phase 7's
"diagnose via security groups" task both assume a real AWS-hosted
node, which a local-only cluster (our original plan) couldn't provide.

## 2. SSM Parameter Store instead of AWS Secrets Manager

**Original ask:** Store and retrieve secrets via AWS Secrets Manager.

**Decision:** Use AWS Systems Manager Parameter Store (`SecureString`,
Standard tier) instead.

**Why:** Secrets Manager has no permanent free tier - every secret
costs $0.40/month indefinitely (only a 30-day trial, or general account
credit for very new accounts). Parameter Store's Standard tier supports
up to 10,000 parameters, encrypted with the default AWS-managed KMS key,
for $0.00/month forever. We lose Secrets Manager's automatic rotation
and cross-region replication - neither of which this project needs,
since we have no RDS/Redshift credentials to rotate and run in a
single region.

## 3. No NAT Gateway / no extra public IPv4 addresses

**Original ask (implied by "VPC with public & private subnets"):** A
typical enterprise VPC routes private-subnet egress through a NAT
Gateway.

**Decision:** Private subnets exist (for the IaC exercise and future
use) but have no route to the internet. No NAT Gateway and no Elastic
IPs are created anywhere in this project; the one EC2 instance uses its
auto-assigned public IP (free while running, released on stop) rather
than a persistent Elastic IP.

**Why:** A NAT Gateway costs ~$32+/month just for existing, before any
data even flows through it. Separately, since February 2024, AWS
charges ~$3.65/month for *every* public IPv4 address in an account,
attached or not - so we avoid allocating any beyond the one the
instance already gets for free while running. Nothing currently
deployed needs outbound internet from a private subnet.

## 4. Self-hosted GitHub Actions runner instead of an internet-facing API server

**The problem:** The CD pipeline needs to run `kubectl`/`helm` against
the cluster. The cluster's security group restricts the Kubernetes API
(port 6443) to one specific IP - ours. GitHub-hosted runners use
constantly-changing IPs, so they could never pass that rule.

**Decision:** Install a GitHub Actions self-hosted runner directly on
the EC2 node, registered with the label `k8s-node`. The `deploy-dev`,
`deploy-test`, and `deploy-prod` jobs run on this runner (`runs-on:
[self-hosted, k8s-node]`), so `kubectl`/`helm` talk to `localhost` - no
path to the cluster is ever opened to the internet.

**Why not just open port 6443 to `0.0.0.0/0`?** That's a legitimate,
common pattern (it's how EKS/GKE public endpoints work, secured by TLS
client certs rather than network isolation) - but it would also mean
storing a cluster-admin kubeconfig in GitHub Secrets, a far more
sensitive credential to leak than anything else in this project. The
self-hosted runner avoids that trade-off entirely, at no extra cost,
since the node already exists.

**Trade-off accepted:** CD is only available while the EC2 instance is
running. In practice this is fine - the instance is something we
deliberately start/stop per session anyway, and a queued deploy job
just waits for the runner to come back online rather than failing.