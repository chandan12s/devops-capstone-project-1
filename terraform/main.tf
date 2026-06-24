terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # State is stored locally (terraform.tfstate, gitignored) for this
  # learning project. In a real team you'd use a remote backend (S3 +
  # DynamoDB lock table) - skipped here to avoid any extra moving parts,
  # since S3 storage for a tiny state file is free-tier anyway but adds
  # setup complexity we don't need yet.
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
    }
  }
}
