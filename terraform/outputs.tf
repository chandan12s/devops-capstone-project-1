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

output "k8s_node_public_ip" {
  value = aws_instance.k8s_node.public_ip
}

output "ssh_command" {
  description = "Run this to SSH into the Kubernetes node"
  value       = "ssh -i ~/.ssh/devops-capstone-key ubuntu@${aws_instance.k8s_node.public_ip}"
}

output "ecr_repository_url" {
  description = "Use this to tag/push images, and to replace REPLACE_ME in k8s/deployment.yaml and helm/task-api/values.yaml"
  value       = aws_ecr_repository.app.repository_url
}