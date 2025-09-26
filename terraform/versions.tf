# © 2025 BioTeam, LLC All rights reserved.
# Terraform and Provider Version Constraints

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 0.70"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

# AWS Provider
provider "aws" {
}

# AWS Cloud Control Provider
provider "awscc" {
}