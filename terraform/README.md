# Terraform - AWS Infrastructure

Provisions, at zero ongoing cost:
- A VPC with 2 public + 2 private subnets across 2 AZs
- An Internet Gateway + public route table (no NAT Gateway - see `../docs/architecture-decisions.md`)
- A GitHub OIDC provider + IAM role, scoped to this repo only
- An SSM Parameter Store secret (placeholder value)
- A CloudWatch Log Group with 7-day retention

## Prerequisites

1. [Install Terraform](https://developer.hashicorp.com/terraform/install) (>= 1.5.0)
2. [Install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
3. Configure AWS credentials locally:
   ```bash
   aws configure
   ```
   Use an IAM user with sufficient permissions for this project (VPC, IAM,
   SSM, CloudWatch Logs). For a learning project, attaching `AdministratorAccess`
   to a dedicated IAM user (not root) is acceptable - just don't reuse those
   keys anywhere else, and don't commit them.

## Setup

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: set github_repo to "your-username/devops-capstone-project"

terraform init
terraform plan      # review what will be created - read this output carefully
terraform apply     # type 'yes' to confirm
```

`terraform apply` will print outputs including `github_actions_role_arn`.

## After apply: set the real secret value

The Terraform code only creates a *placeholder* secret (`REPLACE_ME_VIA_AWS_CLI`).
Set the real value directly via AWS CLI - never put real secret values in
Terraform code or commit them to Git:

```bash
aws ssm put-parameter \
  --name "/devops-capstone/demo/api-key" \
  --value "some-real-looking-api-key-value" \
  --type SecureString \
  --overwrite \
  --region ap-south-1
```

## Wire up GitHub Actions

1. Copy the `github_actions_role_arn` output value.
2. GitHub repo → **Settings → Secrets and variables → Actions → Variables tab**
   → **New repository variable** → name it `AWS_ROLE_ARN`, paste the role ARN.
   (It's a variable, not a secret - an ARN isn't sensitive on its own.)
3. Push to `develop` or `main` and check the **Actions** tab - the
   `verify-secrets` job should succeed and print the retrieved secret's
   length (never its actual value).

## Tearing down

Since everything here is genuinely free, there's no cost pressure to
destroy it - but it's still good practice once you're done experimenting:

```bash
terraform destroy
```
