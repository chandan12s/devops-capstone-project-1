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
