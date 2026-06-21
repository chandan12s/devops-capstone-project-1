# Architecture Decisions

This project intentionally deviates from a "textbook" AWS enterprise
setup in a few places. Each deviation below is a deliberate cost
decision, not a shortcut taken out of ignorance - documented here so
the reasoning is explainable in an interview or review.

## 1. Local Kind cluster instead of Amazon EKS

**Original ask:** Provision an EKS cluster with managed node groups.

**Decision:** Use [Kind](https://kind.sigs.k8s.io/) (Kubernetes-in-Docker)
running locally instead.

**Why:** The EKS control plane costs $0.10/hour (~$73/month) with no
free tier, and would run continuously even when idle. Node groups add
further EC2 cost on top. Kind gives an essentially identical `kubectl`
experience (manifests, Services, Deployments, probes, Helm charts all
work unmodified) at zero cost. The trade-off: no real internet-facing
load balancer, no managed control plane HA, and the cluster only exists
while your machine/Docker is running. Acceptable for a learning/demo
project; would not be acceptable for an actual production workload.

## 2. SSM Parameter Store instead of AWS Secrets Manager

**Original ask:** Store and retrieve secrets via AWS Secrets Manager.

**Decision:** Use AWS Systems Manager Parameter Store (`SecureString`,
Standard tier) instead.

**Why:** Secrets Manager has no permanent free tier - every secret
costs $0.40/month indefinitely (only a 30-day trial, or general account
credit for very new accounts). Parameter Store's Standard tier supports
up to 10,000 parameters, encrypted with the default AWS-managed KMS key,
for $0.00/month forever. We lose Secrets Manager's automatic rotation
and cross-region replication - neither of which this project needs, since
we have no RDS/Redshift credentials to rotate and run in a single region.

## 3. No NAT Gateway / no public IPv4 addresses

**Original ask (implied by "VPC with public & private subnets"):** A
typical enterprise VPC routes private-subnet egress through a NAT
Gateway.

**Decision:** Private subnets exist (for the IaC exercise and future
use) but have no route to the internet. No NAT Gateway, no Elastic IPs,
no Load Balancers are created anywhere in this project.

**Why:** A NAT Gateway costs ~$32+/month just for existing, before any
data even flows through it. Separately, since February 2024, AWS charges
~$3.65/month for *every* public IPv4 address in an account, attached or
not. Since nothing in this project currently runs inside AWS (our app
runs in a local Kind cluster), there is nothing that needs outbound
internet access from a private subnet. If this ever became a real
production deployment, adding a NAT Gateway (or, cheaper, VPC Gateway
Endpoints for S3/DynamoDB-style AWS-service traffic) would be a one-line
Terraform change - it's deferred, not designed away.
