# AWS Enterprise DevOps Capstone Project

An end-to-end DevOps platform built around a real Node.js application, covering CI/CD, Infrastructure as Code, containerization, Kubernetes, security, observability, and cost optimization — all on a near-zero AWS budget.

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

The project is structured as eight progressive phases, each targeting a specific DevOps discipline.

### Application layer
A Node.js/Express REST API (`app/`) with structured JSON logging designed to ship directly into CloudWatch Logs. The `/health` endpoint serves as the target for Kubernetes liveness and readiness probes.

### Source control & branching
A three-tier Git workflow (`main` → `develop` → `feature/*`) with PR-only merges, branch protection rules, and Conventional Commits. Documented in `branching-strategy.md`.

### CI/CD pipeline (GitHub Actions)
Automated pipeline triggered on push/PR: lint → unit tests with coverage → Docker build → ECR push → deploy to Kubernetes. GitHub Actions authenticates to AWS using **OIDC** (no stored access keys). A self-hosted runner on the EC2 node handles kubernetes commands without exposing the Kubernetes API to the internet.

### Infrastructure as Code (Terraform)
All AWS resources are declared in `terraform/` and provisioned with `terraform apply`:
- VPC
- EC2 instance (Ubuntu 22.04) bootstrapped as a single-node Kubernetes cluster via `kubeadm`
- AWS ECR repository with scan-on-push and a lifecycle policy (keep last 5 images)
- IAM roles for GitHub Actions (OIDC) and the EC2 node (ECR pull, CloudWatch agent) — no stored credentials anywhere
- SSM Parameter Store for secrets (`SecureString`, KMS-encrypted)
- CloudWatch log group and budget alert

### Containerization & security
Multi-stage Dockerfile: a `deps` stage installs only production dependencies; the `runtime` stage copies them into a minimal `node:20-alpine` image, runs `apk upgrade` at build time to patch OS-level CVEs, and runs the process as a non-root user. ECR's Clair-based scanning flags any CRITICAL findings and fails the pipeline.

### Kubernetes
Plain manifests (`k8s/`) and a Helm chart (`helm/task-api/`) deploy the API as 2 replicas behind a NodePort service. Network policies enforce default-deny egress, allowing only DNS (port 53) and HTTPS (port 443) outbound — proper defence-in-depth rather than an accidental total block.

### Observability
The CloudWatch agent, bootstrapped by `terraform/scripts/bootstrap-k8s.sh`, ships container logs and EC2 CPU/memory metrics to CloudWatch. 

### Key cost decisions
| Enterprise default | This project | Saving |
|---|---|---|
| Amazon EKS ($0.10/hr) | kubeadm on EC2 (t3.small) | ~$73/month |
| AWS Secrets Manager ($0.40/secret/month) | SSM Parameter Store | ~$0.40/month |
| Snyk / SonarQube (paid tier) | `npm audit` + GitHub Dependency Review | $0 |

Full reasoning for each decision is in `docs/architecture-decisions.md`.

---

## 3. Project Structure

```
devops-capstone/
├── app/                          # Node.js Task API
│   ├── src/
│   │   ├── app.js              
│   │   ├── server.js       
│   │   ├── store.js          
│   │   └── routes/tasks.js       
│   ├── tests/
│   │   ├── health.test.js        # Health endpoint tests
│   │   └── tasks.test.js         # Full CRUD + validation tests
│   ├── Dockerfile                # Multi-stage, non-root, Alpine
│   └── package.json
│
├── terraform/                    # AWS infrastructure
│   ├── main.tf             
│   ├── vpc.tf                   
│   ├── ec2.tf                   
│   ├── ecr.tf                   
│   ├── iam.tf                    
│   ├── ssm.tf                   
│   ├── cloudwatch.tf             
│   ├── observability.tf          
│   ├── budget.tf                
│   ├── variables.tf              
│   ├── outputs.tf                
│   └── scripts/
│       ├── bootstrap-k8s.sh      
│       └── refresh-ecr-secret.sh
│
├── k8s/                          # Raw Kubernetes manifests
│   ├── deployment.yaml           
│   ├── service.yaml      
│   ├── netpol-deny-egress.yaml  
│   └── netpol-allow-egress.yaml  
│
├── helm/task-api/                # Helm chart 
│   ├── Chart.yaml
│   ├── values.yaml              
│   └── templates/
│       ├── deployment.yaml
│       └── service.yaml
│
├── docs/
│   ├── architecture-decisions.md        
│   ├── container-security.md             
│   ├── cloudwatch-logs-insights-queries.md
│   ├── networking-rca.md                 
│   └── pipeline-failure-rca.md
│
├── branching-strategy.md         # Git workflow and commit conventions
└── README.md                    
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
terraform plan      
terraform apply     
```

**Set the real SSM secret value**:
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

**Verify the EC2 node is ready**:
```bash
ssh -i ~/.ssh/devops-capstone-key ubuntu@<node-public-ip>
kubectl get nodes 
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

```bash
ssh -i ~/.ssh/devops-capstone-key ubuntu@<node-public-ip>
```

```bash
bash ~/refresh-ecr-secret.sh
```

**Update the image reference** in `k8s/deployment.yaml` — replace `ACCOUNT_ID` and `REGION` with your real values from `terraform output ecr_repository_url`, then apply:

```bash
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

kubectl get pods
kubectl get pods -o wide

kubectl describe pod <pod-name>
```

**Test from your local machine:**
```bash
curl http://<node-public-ip>:30080/health
curl http://<node-public-ip>:30080/api/tasks
```

**Apply Network Policies:**
```bash
kubectl apply -f k8s/netpol-deny-egress.yaml

kubectl apply -f k8s/netpol-allow-egress.yaml
```

**Terminate:**
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

**Tear down:**
```bash
helm uninstall task-api
```

---

## 6. Architecture Decisions

Key places where this project deliberately deviates from a textbook AWS setup — all documented with reasoning in `docs/architecture-decisions.md`:

| Decision | What was chosen | Why |
|---|---|---|
| Kubernetes | kubeadm on EC2 instead of EKS | EKS control plane costs $0.10/hr (~$73/month) with no free tier |
| Secrets | SSM Parameter Store instead of Secrets Manager | Secrets Manager costs $0.40/secret/month; SSM Standard tier is free |
| Network | No NAT Gateway, no Elastic IPs | NAT Gateway costs ~$32/month just for existing; EC2's auto-assigned public IP is free while running |
| CD runner | Self-hosted runner on EC2 node | GitHub-hosted runners use dynamic IPs that can't pass the K8s API security group rule |
| Dependency scanning | `npm audit` + GitHub Dependency Review | Snyk/Sonar/OWASP require API keys or self-hosted servers; `npm audit` is built into npm and free |

---


## 7. Branching Strategy & Git Workflow

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

## 8. CI/CD Pipeline

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

```bash
sudo ./svc.sh install
sudo ./svc.sh start
sudo ./svc.sh status
```

---

## 11. Observability

### Application logs

The Task API emits one structured JSON log line per request to `stdout`:

The CloudWatch agent, bootstrapped by `terraform/scripts/bootstrap-k8s.sh`, tails `/var/log/containers/*.log` on the EC2 node and ships lines to the `/devops-capstone/app` log group in CloudWatch.

### Infrastructure metrics

The CloudWatch agent also ships two EC2 metrics that AWS doesn't provide by default:

| Metric | Namespace | Why it matters |
|---|---|---|
| `cpu_usage_active` | `DevOpsCapstone/EC2` | Overall node CPU load — CloudWatch's default `CPUUtilization` doesn't include iowait |
| `mem_used_percent` | `DevOpsCapstone/EC2` | Memory — EC2 has no built-in memory metric; the agent is the only source |

### CloudWatch alarms

Terraform creates two alarms in `cloudwatch.tf`:

| Alarm | Condition | Action |
|---|---|---|
| `devops-capstone-high-cpu` | CPU > 80% for 2 consecutive 5-minute periods | SNS notification |
| `devops-capstone-high-memory` | Memory > 85% for 2 consecutive 5-minute periods | SNS notification |

*** Name - Chandan S
*** Assignment - Devops capstone project - 1
