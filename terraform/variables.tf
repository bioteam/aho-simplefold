# © 2025 BioTeam, LLC All rights reserved.
# SimpleFold Terraform Module Variables

variable "project_name" {
  description = "Name of the project, used as prefix for resources"
  type        = string
  default     = "simplefold-healthomics"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository for SimpleFold container"
  type        = string
  default     = "simplefold"
}

variable "execution_role_name" {
  description = "Name of the IAM role for HealthOmics execution"
  type        = string
  default     = "HealthOmicsExecutionRole-SimpleFold"
}

variable "workflow_name" {
  description = "Name of the HealthOmics workflow"
  type        = string
  default     = "SimpleFoldWorkflow"
}

variable "author_name" {
  description = "Author name for workflow metadata"
  type        = string
  default     = "AWS User"
}

variable "storage_capacity" {
  description = "Storage capacity in GiB for the workflow"
  type        = number
  default     = 1200
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}