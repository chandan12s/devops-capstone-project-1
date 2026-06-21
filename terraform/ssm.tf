# Free alternative to AWS Secrets Manager (see docs/architecture-decisions.md).
# Uses the default AWS-managed KMS key (alias/aws/ssm) for encryption -
# customer-managed keys cost $1/month, the default managed key is free.

resource "aws_ssm_parameter" "demo_api_key" {
  name        = "/${var.project_name}/demo/api-key"
  description = "Example secret for the capstone - demonstrates dynamic retrieval in CI/CD"
  type        = "SecureString"

  # Placeholder only. Never put a real secret value in Terraform code or
  # state. After `terraform apply`, set the real value directly via the
  # AWS CLI (see README) - Terraform will not overwrite it on future
  # applies because of the lifecycle rule below.
  value = "REPLACE_ME_VIA_AWS_CLI"

  lifecycle {
    ignore_changes = [value]
  }
}
