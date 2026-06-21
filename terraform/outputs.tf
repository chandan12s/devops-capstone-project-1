output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "github_actions_role_arn" {
  description = "Paste this into a GitHub repo variable named AWS_ROLE_ARN"
  value       = aws_iam_role.github_actions.arn
}

output "ssm_parameter_name" {
  value = aws_ssm_parameter.demo_api_key.name
}

output "cloudwatch_log_group_name" {
  value = aws_cloudwatch_log_group.app.name
}
