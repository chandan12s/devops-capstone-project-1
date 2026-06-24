variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1" # Mumbai - closest region for India-based usage
}

variable "project_name" {
  description = "Short name used as a prefix/tag on all resources"
  type        = string
  default     = "devops-capstone"
}

variable "github_repo" {
  description = "Your GitHub repo in 'owner/repo' form. Used to scope the OIDC trust policy so ONLY this repo's Actions workflows can assume the AWS role."
  type        = string
  # No default on purpose - you must set this in terraform.tfvars
}

variable "my_ip_cidr" {
  description = "Your current public IP in CIDR form (e.g. 49.x.x.x/32). Find it with: curl -s ifconfig.me. Restricts SSH and Kubernetes API access to just you."
  type        = string
}

variable "ssh_public_key" {
  description = "Contents of your SSH public key file (e.g. ~/.ssh/id_ed25519.pub), used to create the AWS key pair for the EC2 instance."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the Kubernetes node. t3.medium gives comfortable headroom for kubeadm; t3.small is cheaper but tighter on memory."
  type        = string
  default     = "t3.small"
}

variable "budget_alert_email" {
  description = "Email address to receive AWS Budget alert notifications"
  type        = string
}