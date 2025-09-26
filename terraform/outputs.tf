# © 2025 BioTeam, LLC All rights reserved.
# SimpleFold Terraform Module Outputs

output "s3_bucket_name" {
  description = "Name of the S3 bucket for workflow data"
  value       = aws_s3_bucket.simplefold_bucket.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.simplefold_bucket.arn
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.simplefold_repo.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.simplefold_repo.arn
}

output "execution_role_arn" {
  description = "ARN of the HealthOmics execution role"
  value       = aws_iam_role.healthomics_execution_role.arn
}

output "execution_role_name" {
  description = "Name of the HealthOmics execution role"
  value       = aws_iam_role.healthomics_execution_role.name
}

output "workflow_id" {
  description = "ID of the HealthOmics workflow"
  value       = awscc_omics_workflow.simplefold_workflow.id
}

output "workflow_arn" {
  description = "ARN of the HealthOmics workflow"
  value       = awscc_omics_workflow.simplefold_workflow.arn
}

output "workflow_name" {
  description = "Name of the HealthOmics workflow"
  value       = awscc_omics_workflow.simplefold_workflow.name
}

output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS Region"
  value       = data.aws_region.current.name
}

output "docker_push_commands" {
  description = "Commands to build and push Docker image to ECR"
  value = {
    login_command = "aws ecr get-login-password --region ${data.aws_region.current.name} | docker login --username AWS --password-stdin ${aws_ecr_repository.simplefold_repo.repository_url}"
    build_command = "docker build --platform=linux/amd64 -t ${var.ecr_repository_name} ."
    tag_command   = "docker tag ${var.ecr_repository_name}:latest ${aws_ecr_repository.simplefold_repo.repository_url}:latest"
    push_command  = "docker push ${aws_ecr_repository.simplefold_repo.repository_url}:latest"
  }
}

output "next_steps" {
  description = "Instructions for next steps after Terraform deployment"
  value = {
    upload_data = "Upload your FASTA files to: s3://${aws_s3_bucket.simplefold_bucket.bucket}/input/"
    build_image = "Run the docker commands from the 'docker_push_commands' output to build and push your container"
    run_workflow = "Use the workflow_id to create runs in the AWS HealthOmics console or via CLI"
  }
}