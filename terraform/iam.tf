# Lets GitHub Actions assume an AWS role using short-lived, automatically
# rotated credentials - no AWS access keys stored in GitHub Secrets.
# This is the modern, recommended pattern (replaces static IAM user keys).

data "tls_certificate" "github_oidc" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_oidc.certificates[0].sha1_fingerprint]
}

resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-github-actions"

  # Trust policy: ONLY workflows running in YOUR specific GitHub repo can
  # assume this role. Any other repo's Actions runs would be rejected.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
          }
        }
      }
    ]
  })
}

# Least-privilege policy: this role can ONLY read our specific SSM
# parameters. We'll attach more (e.g. ECR push) in Phase 4 as needed -
# never grant broad access "just in case".
resource "aws_iam_role_policy" "github_actions_ssm_read" {
  name = "${var.project_name}-ssm-read"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters"]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/${var.project_name}/*"
      }
    ]
  })
}
