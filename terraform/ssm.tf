resource "aws_ssm_parameter" "demo_api_key" {
  name        = "/${var.project_name}/demo/api-key"
  description = "Example secret for the capstone - demonstrates dynamic retrieval in CI/CD"
  type        = "SecureString"

  value = "REPLACE_ME_VIA_AWS_CLI"

  lifecycle {
    ignore_changes = [value]
  }
}
