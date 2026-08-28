# AWS Enterprise DevOps Capstone Project

An end-to-end DevOps platform built around a real Node.js application, covering CI/CD, Infrastructure as Code, containerization, Kubernetes, security, observability, and cost optimization — all on a near-zero AWS budget.

---

## Table of Contents

1. [Problem Statement](#1-problem-statement)
2. [Solution Approach](#2-solution-approach)
3. [Project Structure](#3-project-structure)
4. [Dependencies & Setup](#4-dependencies--setup)
5. [Execution Steps](#5-execution-steps)
   - [Phase 1 — Run the app locally](#phase-1--run-the-app-locally)
   - [Phase 2 — Provision AWS infrastructure](#phase-2--provision-aws-infrastructure)
   - [Phase 3 — Build & push the Docker image](#phase-3--build--push-the-docker-image)
   - [Phase 4 — Deploy to Kubernetes](#phase-4--deploy-to-kubernetes)
   - [Phase 5 — Helm-based deployment](#phase-5--helm-based-deployment)
6. [API Reference](#6-api-reference)
7. [Architecture Decisions](#7-architecture-decisions)
8. [Project Status](#8-project-status)

---

## 1. Problem Statement

Modern software teams are expected to ship reliably and repeatedly — not just write code. The gap between "app works on my machine" and "app runs securely in production with automated pipelines, infrastructure as code, and observable systems" is exactly what this project addresses.

Specifically, this capstone tackles the following engineering challenges:

- **No automated delivery pipeline** — code changes need a reproducible, gated path from commit to production without manual steps.
- **No infrastructure consistency** — provisioning cloud resources by hand is error-prone and impossible to audit or reproduce.
- **No container security posture** — shipping application images without scanning for OS-level CVEs or running as root is a common but serious gap.
- **No Kubernetes operational experience** — understanding deployments, probes, network policies, and Helm charts requires hands-on practice.
- **No observability** — without structured logs and metrics flowing into a central system, diagnosing production issues is guesswork.
- **Cost constraint** — real enterprise tooling (EKS, NAT Gateways, Secrets Manager) costs hundreds of dollars a month; learning the same skills must be possible on a near-zero budget.

The subject application is a simple **Node.js Task API** (Express, in-memory store, full CRUD) — intentionally minimal so the DevOps layer is the point of the exercise, not the application logic.

---

## 2. Solution Approach

The project is structured as eight progressive phases, each targeting a specific DevOps discipline. Every phase produces real, working artifacts — not just configuration files.

### Application layer
A Node.js/Express REST API (`app/`) with structured JSON logging designed to ship directly into CloudWatch Logs. The `/health` endpoint serves as the target for Kubernetes liveness and readiness probes.

### Source control & branching
A three-tier Git workflow (`main` → `develop` → `feature/*`) with PR-only merges, branch protection rules, and Conventional Commits. Documented in `branching-strategy.md`.

### CI/CD pipeline (GitHub Actions)
Automated pipeline triggered on push/PR: lint → unit tests with coverage → Docker build → ECR push → deploy to Kubernetes. GitHub Actions authenticates to AWS using **OIDC** (no stored access keys). A self-hosted runner on the EC2 node handles `kubectl`/`helm` commands without exposing the Kubernetes API to the internet.

### Infrastructure as Code (Terraform)
All AWS resources are declared in `terraform/` and provisioned with `terraform apply`:
- VPC with 2 public + 2 private subnets across 2 availability zones
- EC2 instance (Ubuntu 22.04) bootstrapped as a single-node Kubernetes cluster via `kubeadm`
- AWS ECR repository with scan-on-push and a lifecycle policy (keep last 5 images)
- IAM roles for GitHub Actions (OIDC) and the EC2 node (ECR pull, CloudWatch agent) — no stored credentials anywhere
- SSM Parameter Store for secrets (`SecureString`, KMS-encrypted)
- CloudWatch log group (7-day retention) and budget alert

### Containerization & security
Multi-stage Dockerfile: a `deps` stage installs only production dependencies; the `runtime` stage copies them into a minimal `node:20-alpine` image, runs `apk upgrade` at build time to patch OS-level CVEs, and runs the process as a non-root user. ECR's Clair-based scanning flags any CRITICAL findings and fails the pipeline.

### Kubernetes
Plain manifests (`k8s/`) and a Helm chart (`helm/task-api/`) deploy the API as 2 replicas behind a NodePort service. Network policies enforce default-deny egress, allowing only DNS (port 53) and HTTPS (port 443) outbound — proper defence-in-depth rather than an accidental total block.

### Observability
The CloudWatch agent, bootstrapped by `terraform/scripts/bootstrap-k8s.sh`, ships container logs and EC2 CPU/memory metrics to CloudWatch. Structured JSON log lines (timestamp, method, path, statusCode, durationMs) are designed for Logs Insights queries documented in `docs/cloudwatch-logs-insights-queries.md`.

### Key cost decisions
| Enterprise default | This project | Saving |
|---|---|---|
| Amazon EKS ($0.10/hr) | kubeadm on EC2 (t3.small) | ~$73/month |
| AWS Secrets Manager ($0.40/secret/month) | SSM Parameter Store | ~$0.40/month |
| NAT Gateway (~$32/month) | No NAT Gateway (private subnets have no internet route) | ~$32/month |
| Snyk / SonarQube (paid tier) | `npm audit` + GitHub Dependency Review | $0 |

Full reasoning for each decision is in `docs/architecture-decisions.md`.

---

## 3. Project Structure

```
devops-capstone/
├── app/                          # Node.js Task API
│   ├── src/
│   │   ├── app.js                # Express app + request logging middleware
│   │   ├── server.js             # HTTP server entry point
│   │   ├── store.js              # In-memory task store (CRUD + validation)
│   │   └── routes/tasks.js       # /api/tasks route handlers
│   ├── tests/
│   │   ├── health.test.js        # Health endpoint tests
│   │   └── tasks.test.js         # Full CRUD + validation tests
│   ├── Dockerfile                # Multi-stage, non-root, Alpine
│   └── package.json
│
├── terraform/                    # AWS infrastructure (IaC)
│   ├── main.tf                   # Provider config + backend
│   ├── vpc.tf                    # VPC, subnets, IGW, route tables
│   ├── ec2.tf                    # EC2 instance + security group + IAM profile
│   ├── ecr.tf                    # ECR repo + lifecycle policy
│   ├── iam.tf                    # GitHub OIDC provider + Actions role
│   ├── ssm.tf                    # SSM Parameter Store secret
│   ├── cloudwatch.tf             # Log group + metric alarms
│   ├── observability.tf          # CloudWatch agent config
│   ├── budget.tf                 # AWS Budget alert
│   ├── variables.tf              # Input variable declarations
│   ├── outputs.tf                # Key outputs (ECR URL, EC2 IP, role ARN)
│   ├── terraform.tfvars.example  # Template — copy to terraform.tfvars
│   └── scripts/
│       ├── bootstrap-k8s.sh      # EC2 user_data: installs kubeadm + CloudWatch agent
│       └── refresh-ecr-secret.sh # Refreshes the K8s ECR pull secret (expires ~12h)
│
├── k8s/                          # Raw Kubernetes manifests
│   ├── deployment.yaml           # 2-replica Deployment + probes + resource limits
│   ├── service.yaml              # NodePort service on :30080
│   ├── netpol-deny-egress.yaml   # Default-deny all egress (troubleshooting artifact)
│   └── netpol-allow-egress.yaml  # Fixed policy: allow DNS + HTTPS only
│
├── helm/task-api/                # Helm chart (same manifests, parameterised)
│   ├── Chart.yaml
│   ├── values.yaml               # Defaults: image, replicas, resources, probes
│   └── templates/
│       ├── deployment.yaml
│       └── service.yaml
│
├── docs/
│   ├── architecture-decisions.md         # Why this project deviates from "textbook" AWS
│   ├── container-security.md             # ECR scan findings + remediation log
│   ├── cloudwatch-logs-insights-queries.md
│   ├── networking-rca.md                 # Network policy incident RCA
│   └── pipeline-failure-rca.md
│
├── branching-strategy.md         # Git workflow and commit conventions
└── README.md                     # This file
```

---

## 4. Dependencies & Setup

### Required tools

| Tool | Version | Install |
|---|---|---|
| Node.js | >= 18.0.0 | [nodejs.org](https://nodejs.org) |
| npm | >= 9 (bundled with Node) | — |
| Docker | >= 24 | [docs.docker.com/get-docker](https://docs.docker.com/get-docker) |
| Terraform | >= 1.5.0 | [developer.hashicorp.com/terraform/install](https://developer.hashicorp.com/terraform/install) |
| AWS CLI | >= 2 | [docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| kubectl | >= 1.28 | [kubernetes.io/docs/tasks/tools](https://kubernetes.io/docs/tasks/tools) |
| Helm | >= 3.14 | [helm.sh/docs/intro/install](https://helm.sh/docs/intro/install) |

### AWS account setup

1. Create a dedicated IAM user (do **not** use the root account).
2. Attach `AdministratorAccess` to that user (acceptable for a learning project — do not reuse these keys elsewhere).
3. Configure the AWS CLI:
   ```bash
   aws configure
   # Enter: Access Key ID, Secret Access Key, region (ap-south-1), output format (json)
   ```
4. Find your current public IP — you'll need it for `terraform.tfvars`:
   ```bash
   curl -s ifconfig.me
   ```
5. Generate an SSH key pair for the EC2 node (skip if you already have one):
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/devops-capstone-key
   ```

### terraform.tfvars setup

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and fill in every field:

```hcl
aws_region   = "ap-south-1"
project_name = "devops-capstone"

# Your GitHub repo in "owner/repo" form — scopes the OIDC trust policy
github_repo = "your-github-username/devops-capstone-project"

# Your current public IP with /32 suffix (restricts SSH + K8s API access to just you)
my_ip_cidr = "203.0.113.5/32"

# Contents of your SSH public key file
ssh_public_key = "ssh-ed25519 AAAA... your-email@example.com"

instance_type      = "t3.small"     # t3.medium if you need more headroom
budget_alert_email = "you@example.com"
```

---

## 5. Execution Steps

### Phase 1 — Run the app locally

```bash
cd app
npm install
npm start          # starts the API on http://localhost:3000
```

For auto-reload during development:
```bash
npm run dev
```

Run the test suite (Jest + Supertest, with coverage):
```bash
npm test
```

Lint the source:
```bash
npm run lint
```

**Smoke test the API:**
```bash
# Health check
curl http://localhost:3000/health

# Create a task
curl -X POST http://localhost:3000/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"Learn Kubernetes","description":"Deploy a real app on K8s"}'

# List all tasks
curl http://localhost:3000/api/tasks

# Filter by completion status
curl "http://localhost:3000/api/tasks?completed=false"

# Update a task
curl -X PUT http://localhost:3000/api/tasks/1 \
  -H "Content-Type: application/json" \
  -d '{"completed":true}'

# Delete a task
curl -X DELETE http://localhost:3000/api/tasks/1
```

---

### Phase 2 — Provision AWS infrastructure

```bash
cd terraform
terraform init
terraform plan      # read the output carefully before proceeding
terraform apply     # type 'yes' to confirm
```

Note the key outputs — you'll need them in later steps:
```
ecr_repository_url       = "123456789.dkr.ecr.ap-south-1.amazonaws.com/devops-capstone/task-api"
github_actions_role_arn  = "arn:aws:iam::123456789:role/devops-capstone-github-actions"
k8s_node_public_ip       = "13.x.x.x"
ssh_command              = "ssh -i ~/.ssh/devops-capstone-key ubuntu@13.x.x.x"
```

**Set the real SSM secret value** (never put real values in Terraform):
```bash
aws ssm put-parameter \
  --name "/devops-capstone/demo/api-key" \
  --value "your-actual-secret-value" \
  --type SecureString \
  --overwrite \
  --region ap-south-1
```

**Wire up GitHub Actions:**
1. Copy the `github_actions_role_arn` output value.
2. Go to your GitHub repo → **Settings → Secrets and variables → Actions → Variables tab**.
3. Click **New repository variable**, name it `AWS_ROLE_ARN`, and paste the ARN.

**Verify the EC2 node is ready** (bootstrap takes ~5 minutes):
```bash
ssh -i ~/.ssh/devops-capstone-key ubuntu@<node-public-ip>
kubectl get nodes    # STATUS should be "Ready"
```

**Tear down when done for the session** (stop costs money while running):
```bash
# Stop the instance to pause billing, or destroy everything:
terraform destroy
```

---

### Phase 3 — Build & push the Docker image

Run these commands from your **local machine** (not the EC2 node):

```bash
# Set variables from Terraform output
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="ap-south-1"
ECR_URL="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/devops-capstone/task-api"

# Authenticate Docker to ECR
aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

# Build the image
cd app
docker build -t task-api:v1 .

# Quick local smoke test before pushing
docker run --rm -p 3000:3000 task-api:v1
curl http://localhost:3000/health   # should return {"status":"ok",...}
# Ctrl+C to stop

# Tag and push to ECR
docker tag task-api:v1 "${ECR_URL}:v1"
docker push "${ECR_URL}:v1"
```

Check for scan findings after the push (ECR scans automatically):
```bash
aws ecr describe-image-scan-findings \
  --repository-name "devops-capstone/task-api" \
  --image-id imageTag=v1 \
  --region $REGION
```

---

### Phase 4 — Deploy to Kubernetes

All `kubectl` commands run **on the EC2 node** (SSH in first):

```bash
ssh -i ~/.ssh/devops-capstone-key ubuntu@<node-public-ip>
```

**Create the ECR pull secret** (must be refreshed every ~12 hours):
```bash
bash ~/refresh-ecr-secret.sh
```

**Update the image reference** in `k8s/deployment.yaml` — replace `ACCOUNT_ID` and `REGION` with your real values from `terraform output ecr_repository_url`, then apply:

```bash
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Verify pods are running
kubectl get pods
kubectl get pods -o wide

# Confirm probes are passing
kubectl describe pod <pod-name>
```

**Test from your local machine:**
```bash
curl http://<node-public-ip>:30080/health
curl http://<node-public-ip>:30080/api/tasks
```

**Apply Network Policies:**
```bash
# Default-deny all egress (for troubleshooting exercise)
kubectl apply -f k8s/netpol-deny-egress.yaml

# Fixed policy: allow DNS + HTTPS only
kubectl apply -f k8s/netpol-allow-egress.yaml
```

**Tear down:**
```bash
kubectl delete -f k8s/deployment.yaml -f k8s/service.yaml
```

---

### Phase 5 — Helm-based deployment

Run on the **EC2 node**, with the Helm chart copied from `helm/task-api/`:

```bash
# Set the ECR URL
ECR_URL="<your-ecr-repository-url>"

# Clean up raw kubectl manifests first (avoids port conflicts)
kubectl delete -f k8s/deployment.yaml -f k8s/service.yaml 2>/dev/null || true

# Install via Helm
helm install task-api ~/helm/task-api \
  --set image.repository=${ECR_URL} \
  --set image.tag=v1

# Verify the release
helm list
helm status task-api
kubectl get pods
```

**Upgrade** (e.g. scale replicas or change image tag):
```bash
helm upgrade task-api ~/helm/task-api \
  --set replicaCount=3 \
  --set image.repository=${ECR_URL} \
  --set image.tag=v2

helm history task-api    # view rollout history
```

**Roll back** to a previous revision:
```bash
helm rollback task-api 1
```

**Tear down:**
```bash
helm uninstall task-api
```

---

## 6. API Reference

Base URL (local): `http://localhost:3000`  
Base URL (on K8s): `http://<node-public-ip>:30080`

| Method | Path | Request body | Success | Description |
|---|---|---|---|---|
| `GET` | `/health` | — | `200` | Kubernetes liveness/readiness probe |
| `GET` | `/api/tasks` | — | `200` | List all tasks. Optional query param: `?completed=true\|false` |
| `POST` | `/api/tasks` | `{ "title": "string", "description"?: "string" }` | `201` | Create a new task |
| `GET` | `/api/tasks/:id` | — | `200` | Fetch a single task by ID |
| `PUT` | `/api/tasks/:id` | `{ "title"?: "string", "description"?: "string", "completed"?: boolean }` | `200` | Update one or more fields |
| `DELETE` | `/api/tasks/:id` | — | `204` | Delete a task |

**Validation rules:**
- `title` is required on create; must be a non-empty string, max 100 characters.
- `description` is optional; must be a string if provided.
- Unknown task IDs return `404`.
- Validation failures return `400` with an `errors` array.

---

## 7. Architecture Decisions

Key places where this project deliberately deviates from a textbook AWS setup — all documented with reasoning in `docs/architecture-decisions.md`:

| Decision | What was chosen | Why |
|---|---|---|
| Kubernetes | kubeadm on EC2 instead of EKS | EKS control plane costs $0.10/hr (~$73/month) with no free tier |
| Secrets | SSM Parameter Store instead of Secrets Manager | Secrets Manager costs $0.40/secret/month; SSM Standard tier is free |
| Network | No NAT Gateway, no Elastic IPs | NAT Gateway costs ~$32/month just for existing; EC2's auto-assigned public IP is free while running |
| CD runner | Self-hosted runner on EC2 node | GitHub-hosted runners use dynamic IPs that can't pass the K8s API security group rule |
| Dependency scanning | `npm audit` + GitHub Dependency Review | Snyk/Sonar/OWASP require API keys or self-hosted servers; `npm audit` is built into npm and free |

---

## 8. Project Status

| Phase | Description | Status |
|---|---|---|
| 1 | Source control & branching strategy | ✅ Complete |
| 2 | CI/CD pipeline (GitHub Actions) | 🔄 In progress |
| 3 | Infrastructure as Code (Terraform) | 🔄 In progress |
| 4 | Containerization & Kubernetes | 🔄 In progress |
| 5 | Observability (CloudWatch logs + metrics) | 🔄 In progress |
| 6 | DevSecOps (ECR scanning, OIDC, network policies) | 🔄 In progress |
| 7 | Troubleshooting (RCAs, network policy incident) | 🔄 In progress |
| 8 | Cost optimization | 🔄 In progress |

---

## 9. Branching Strategy & Git Workflow

This project uses a three-tier Git branching model that mirrors how most product teams operate a single production service.

### Branch structure

| Branch | Purpose | Protected | Deploys to |
|---|---|---|---|
| `main` | Always reflects production code | ✅ Yes | Production |
| `develop` | Integration branch for completed features | ✅ Yes | Dev / Test |
| `feature/*` | One branch per feature or fix | ❌ No | Nowhere (local / PR only) |

### Rules

1. **Nobody commits directly to `main` or `develop`.** All changes go through a Pull Request.
2. **Every feature starts from `develop`:**
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/short-description
   ```
3. **A PR is required** to merge `feature/*` → `develop`. At least one review (with actual comments) before merging.
4. **`develop` → `main`** is done via PR only when `develop` is stable and tested. This represents a release.
5. **Branch protection rules** in GitHub (Settings → Branches) enforce all of the above at the platform level.

### Commit message convention

Lightweight [Conventional Commits](https://www.conventionalcommits.org/) style:

```
feat: add task creation endpoint
fix: return 404 for unknown task id
test: add validation tests for task creation
docs: update branching strategy
chore: add .gitignore
ci: add ECR scan step to pipeline
refactor: extract store logic from route handler
```

This keeps `git log` readable and can later auto-generate changelogs.

### Example flow

```
feature/task-api  →  develop  →  main
     (PR #1)          (PR #2, "release")
```

---

## 10. CI/CD Pipeline

The GitHub Actions pipeline lives in `.github/workflows/pipeline.yml`. It triggers on every push to any branch and on PRs targeting `develop` or `main`.

### Pipeline stages

```
push / PR
   │
   ▼
┌─────────────────┐
│   lint + test   │  ESLint + Jest with coverage
└────────┬────────┘
         │ (on develop / main push only)
         ▼
┌─────────────────┐
│ dependency-scan │  npm audit --audit-level=high
└────────┬────────┘
         │
         ▼
┌──────────────────────┐
│  build-and-push-image│  docker build → ECR push → ECR scan → fail on CRITICAL
└────────┬─────────────┘
         │
         ▼
┌────────────────┐   ┌────────────────┐   ┌────────────────┐
│  deploy-dev    │ → │  deploy-test   │ → │  deploy-prod   │
│  (develop)     │   │  (develop)     │   │  (main only)   │
└────────────────┘   └────────────────┘   └────────────────┘
```

### Key pipeline behaviours

**Authentication:** Uses GitHub's OIDC provider with the IAM role created by Terraform. No AWS access keys are stored in GitHub Secrets — the pipeline assumes the role dynamically on each run.

**ECR scan gate:** After pushing the image, the pipeline calls `aws ecr describe-image-scan-findings` and fails the build if any `CRITICAL` severity finding is reported. Scan results are uploaded as a downloadable workflow artifact (`ecr-scan-findings`) on every run regardless of pass/fail.

**Deployment runner:** The `deploy-*` jobs run on a self-hosted GitHub Actions runner installed on the EC2 node (label: `k8s-node`). This lets `kubectl` and `helm` talk to the cluster over `localhost` without exposing the Kubernetes API port (6443) to the internet.

**Environment promotion:**
- Push to `develop` → deploys to `dev` namespace, then `test` namespace (automated)
- Push to `main` → deploys to `prod` namespace (requires manual approval gate)

### Setting up the self-hosted runner

SSH into the EC2 node, then follow the runner registration steps from your GitHub repo:

```
GitHub repo → Settings → Actions → Runners → New self-hosted runner
```

Select **Linux / x64**, copy the configuration commands, run them on the node, and register with the label `k8s-node`. Start the runner as a service:

```bash
sudo ./svc.sh install
sudo ./svc.sh start
sudo ./svc.sh status
```

---

## 11. Observability

### Application logs

The Task API emits one structured JSON log line per request to `stdout`:

```json
{
  "timestamp": "2026-06-28T10:23:45.123Z",
  "method": "POST",
  "path": "/api/tasks",
  "statusCode": 201,
  "durationMs": 4
}
```

The CloudWatch agent, bootstrapped by `terraform/scripts/bootstrap-k8s.sh`, tails `/var/log/containers/*.log` on the EC2 node and ships lines to the `/devops-capstone/app` log group in CloudWatch.

### Infrastructure metrics

The CloudWatch agent also ships two EC2 metrics that AWS doesn't provide by default:

| Metric | Namespace | Why it matters |
|---|---|---|
| `cpu_usage_active` | `DevOpsCapstone/EC2` | Overall node CPU load — CloudWatch's default `CPUUtilization` doesn't include iowait |
| `mem_used_percent` | `DevOpsCapstone/EC2` | Memory — EC2 has no built-in memory metric; the agent is the only source |

Metrics are collected every 60 seconds. The agent is configured in `/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json` (written during bootstrap).

### Useful CloudWatch Logs Insights queries

Run these in CloudWatch → Logs Insights → select log group `/devops-capstone/app`:

**Request rate by endpoint (last hour):**
```
fields @timestamp, method, path, statusCode
| filter ispresent(method)
| stats count() as requests by path
| sort requests desc
```

**Error rate (4xx + 5xx):**
```
fields @timestamp, method, path, statusCode, durationMs
| filter statusCode >= 400
| stats count() as errors by statusCode, path
| sort errors desc
```

**P95 response time per endpoint:**
```
fields @timestamp, path, durationMs
| filter ispresent(durationMs)
| stats pct(durationMs, 95) as p95_ms by path
| sort p95_ms desc
```

**Slowest requests (top 20):**
```
fields @timestamp, method, path, statusCode, durationMs
| sort durationMs desc
| limit 20
```

### CloudWatch alarms

Terraform creates two alarms in `cloudwatch.tf`:

| Alarm | Condition | Action |
|---|---|---|
| `devops-capstone-high-cpu` | CPU > 80% for 2 consecutive 5-minute periods | SNS notification |
| `devops-capstone-high-memory` | Memory > 85% for 2 consecutive 5-minute periods | SNS notification |

### Checking agent status on the node

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a status

# Tail agent logs if something looks wrong
sudo tail -f /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log
```

---

## 12. Container Security

### Image hardening

The `app/Dockerfile` applies four layers of security before any scan ever runs:

1. **Alpine base image** (`node:20-alpine`) — drastically fewer installed OS packages compared to the full Debian-based `node:20`, which means fewer possible CVEs.
2. **Multi-stage build** — `devDependencies` (eslint, jest, nodemon, supertest) are installed in the `deps` build stage and never copied into the final image.
3. **`apk upgrade` at build time** — `RUN apk update && apk upgrade --no-cache` in the runtime stage pulls Alpine's current patched packages on every build, regardless of how old the cached base image layer is.
4. **Non-root user** — the process runs as `appuser` (UID 1001), so even a compromised dependency can't write to the filesystem or escalate privileges inside the container.

### ECR scan-on-push

ECR automatically scans every pushed image using Clair (free on every ECR repository). The pipeline fails if any `CRITICAL` finding is reported.

### Responding to a CRITICAL finding

1. **Check if a base image rebuild fixes it** — Alpine ships frequent security patches:
   ```bash
   docker pull node:20-alpine
   docker build --no-cache -t task-api:test ./app
   ```
   Then re-push and re-check the scan. A fresh build often picks up a patched OS layer.

2. **If it's an npm dependency** — check the `npm-audit-report` artifact from the `dependency-scan` job:
   ```bash
   npm audit
   npm audit fix          # auto-fix compatible updates
   npm audit fix --force  # force major-version bumps (test thoroughly after)
   ```

3. **If it's a false positive or unexploitable code path** — document the reasoning in `docs/container-security.md` under the "Status" column for that CVE. Do not silently disable the scan gate; record the human judgment call explicitly.

4. **Check Alpine's package tracker** for patch availability:
   `https://pkgs.alpinelinux.org/packages?name=openssl`

---

## 13. EC2 Node Bootstrap

When `terraform apply` creates the EC2 instance, the `user_data` script (`terraform/scripts/bootstrap-k8s.sh`) runs automatically on first boot as root. It takes approximately 5 minutes to complete.

### What the bootstrap script does

| Step | What happens |
|---|---|
| 1 | Disables swap (hard kubeadm requirement) |
| 2 | Loads `overlay` and `br_netfilter` kernel modules; sets required sysctl values |
| 3 | Installs `containerd` as the container runtime; enables `SystemdCgroup` |
| 4 | Installs `kubeadm`, `kubelet`, `kubectl` (pinned to v1.33, held from unplanned upgrades) |
| 5 | Installs AWS CLI v2 (needed to authenticate to ECR from the node) |
| 6 | Runs `kubeadm init` with the EC2 public IP added to the API server's TLS SAN list |
| 7 | Copies the admin kubeconfig to both `root` and `ubuntu` home directories |
| 8 | Installs the Flannel CNI plugin for pod-to-pod networking |
| 9 | Removes the control-plane taint so app pods can schedule on this single node |
| 10 | Installs `metrics-server` with `--kubelet-insecure-tls` (self-signed certs on a single node) |
| 11 | Installs Helm 3 |
| 12 | Installs and configures the CloudWatch agent (metrics + log shipping) |

### Monitoring the bootstrap

```bash
# SSH in immediately after terraform apply
ssh -i ~/.ssh/devops-capstone-key ubuntu@<node-public-ip>

# Watch the bootstrap log in real time
sudo tail -f /var/log/k8s-bootstrap.log

# Once "bootstrap complete" appears, verify the cluster
kubectl get nodes
# NAME         STATUS   ROLES           AGE   VERSION
# ip-10-x-x-x  Ready    control-plane   5m    v1.33.x
```

### If the node is not Ready after 10 minutes

```bash
# Check kubelet service status
sudo systemctl status kubelet
sudo journalctl -u kubelet -n 50

# Check if containerd is running
sudo systemctl status containerd

# Re-read the full bootstrap log for errors
sudo cat /var/log/k8s-bootstrap.log | grep -E "ERROR|error|failed|Failed"
```

### ECR pull secret refresh

ECR authorization tokens expire after approximately 12 hours. Run this on the node whenever pod pulls fail with `ImagePullBackOff`:

```bash
bash ~/refresh-ecr-secret.sh
# Output: "ECR pull secret refreshed for <account>.dkr.ecr.ap-south-1.amazonaws.com (valid ~12 hours)."
```

The script uses the node's IAM instance role — no credentials are stored or passed in.

---

## 14. Troubleshooting

### Pod is stuck in `ImagePullBackOff`

```bash
kubectl describe pod <pod-name>    # check the Events section at the bottom
```

**Cause A — ECR secret expired:**
```bash
bash ~/refresh-ecr-secret.sh
kubectl rollout restart deployment/task-api
```

**Cause B — Wrong image URI in the manifest:**  
Open `k8s/deployment.yaml` or `helm/task-api/values.yaml`, confirm the `image.repository` matches `terraform output ecr_repository_url` exactly.

**Cause C — Image tag doesn't exist in ECR:**
```bash
aws ecr list-images --repository-name devops-capstone/task-api --region ap-south-1
```

---

### Pod is stuck in `CrashLoopBackOff`

```bash
kubectl logs <pod-name>                  # current logs
kubectl logs <pod-name> --previous       # logs from the last crash
kubectl describe pod <pod-name>          # check exit code and liveness probe failures
```

Common causes: app failing to bind to the port, a missing environment variable, or the health endpoint returning non-200 before the `initialDelaySeconds` window closes.

---

### App is unreachable at `<node-ip>:30080`

1. **Verify the NodePort service exists:**
   ```bash
   kubectl get svc task-api
   ```
2. **Check the EC2 security group** — port 30080 must be open inbound from your IP. Confirm with:
   ```bash
   aws ec2 describe-security-groups \
     --filters Name=group-name,Values=devops-capstone-k8s-node \
     --query "SecurityGroups[*].IpPermissions" \
     --region ap-south-1
   ```
3. **Check the Network Policy** — if `netpol-deny-egress.yaml` was applied without `netpol-allow-egress.yaml`, pods can't reach DNS and will fail on any outbound call. Confirm with:
   ```bash
   kubectl get networkpolicies
   kubectl apply -f k8s/netpol-allow-egress.yaml   # apply the fix
   ```
4. **Test from inside the cluster** to isolate whether it's a pod or network issue:
   ```bash
   kubectl run debug --image=curlimages/curl --rm -it --restart=Never \
     -- curl http://task-api:3000/health
   ```

---

### Network Policy broke DNS / outbound connectivity

**Symptom:** Pods return `NXDOMAIN` on any hostname lookup, or `curl` to external URLs hangs.  
**Cause:** `netpol-deny-egress.yaml` blocks all egress, including DNS (port 53), making name resolution fail.  
**Fix:**
```bash
kubectl apply -f k8s/netpol-allow-egress.yaml
```
This replaces the deny-all policy with a rule that permits DNS (UDP/TCP 53) and HTTPS (TCP 443), the only two protocols the app actually needs outbound.

Full root-cause analysis in `docs/networking-rca.md`.

---

### Terraform plan / apply fails

**"Error: No valid credential sources found"**  
Run `aws configure` and confirm credentials are set for the `ap-south-1` region.

**"Error acquiring the state lock"**  
A previous `apply` was interrupted. Release the lock:
```bash
terraform force-unlock <lock-id>   # lock ID is shown in the error message
```

**"Error: requested entity already exists" (IAM / SSM)**  
Resources from a previous run weren't fully destroyed. Run `terraform destroy` first or import the existing resource:
```bash
terraform import aws_ssm_parameter.api_key /devops-capstone/demo/api-key
```

---

## 15. Cost Reference

This project is designed to run within the AWS Free Tier and cost a few dollars total across all phases, assuming the EC2 instance is stopped between sessions.

| Resource | Free tier | Notes |
|---|---|---|
| EC2 t3.small | 750 hrs/month (t2.micro only) | t3.small costs ~$0.023/hr; stop when not in use |
| ECR storage | 500 MB/month | Alpine images are ~150 MB; lifecycle policy keeps only last 5 |
| CloudWatch Logs | 5 GB ingestion/month | Structured logs from a dev workload are well under 1 GB |
| CloudWatch Metrics | 10 custom metrics free | Project uses 2 (CPU, memory) |
| CloudWatch Alarms | 10 alarms free | Project creates 2 |
| SSM Parameter Store | 10,000 standard params free | Project uses 1 |
| IAM, VPC, Security Groups | Always free | No per-resource charge |
| AWS Budgets | 2 budgets free | Project creates 1 |
| Data transfer | 1 GB/month free | Dev traffic is negligible |

**To minimize cost during development:** Stop (don't terminate) the EC2 instance after each session:
```bash
# From your local machine
aws ec2 stop-instances \
  --instance-ids $(terraform -chdir=terraform output -raw k8s_node_instance_id) \
  --region ap-south-1

# Start again next session
aws ec2 start-instances \
  --instance-ids $(terraform -chdir=terraform output -raw k8s_node_instance_id) \
  --region ap-south-1
```

The public IP changes on start — update `my_ip_cidr` in `terraform.tfvars` and re-run `terraform apply` if your own IP also changed.

**To destroy everything when done:**
```bash
cd terraform
terraform destroy    # type 'yes' — removes all AWS resources this project created
```
