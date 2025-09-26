# © 2025 BioTeam, LLC All rights reserved.

# SimpleFold AWS HealthOmics Terraform Module
# This module creates the necessary AWS resources for SimpleFold deployment

# Get current AWS account ID and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Create S3 bucket for workflow data
resource "aws_s3_bucket" "simplefold_bucket" {
  bucket = "${var.project_name}-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"

  tags = {
    Name        = "SimpleFold Workflow Bucket"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Enable S3 bucket versioning
resource "aws_s3_bucket_versioning" "simplefold_bucket_versioning" {
  bucket = aws_s3_bucket.simplefold_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Create ECR repository for SimpleFold container
resource "aws_ecr_repository" "simplefold_repo" {
  name = var.ecr_repository_name

  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "SimpleFold Container Repository"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Set ECR lifecycle policy
resource "aws_ecr_lifecycle_policy" "simplefold_repo_policy" {
  repository = aws_ecr_repository.simplefold_repo.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Set ECR repository policy to allow HealthOmics access
resource "aws_ecr_repository_policy" "simplefold_repo_access_policy" {
  repository = aws_ecr_repository.simplefold_repo.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowHealthOmicsAccess"
        Effect = "Allow"
        Principal = {
          Service = "omics.amazonaws.com"
        }
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories",
          "ecr:DescribeImages"
        ]
      },
      {
        Sid    = "AllowHealthOmicsExecutionRoleAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.healthomics_execution_role.arn
        }
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories",
          "ecr:DescribeImages"
        ]
      }
    ]
  })
}

# IAM role for HealthOmics execution
resource "aws_iam_role" "healthomics_execution_role" {
  name = var.execution_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "omics.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "HealthOmics Execution Role"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Attach specific policies to the execution role
# Custom S3 policy for the specific bucket
resource "aws_iam_role_policy" "s3_bucket_access" {
  name = "S3BucketAccess"
  role = aws_iam_role.healthomics_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetObjectVersion",
          "s3:PutObjectAcl",
          "s3:GetObjectAcl"
        ]
        Resource = [
          aws_s3_bucket.simplefold_bucket.arn,
          "${aws_s3_bucket.simplefold_bucket.arn}/*"
        ]
      }
    ]
  })
}

# Custom ECR policy for the specific repository
resource "aws_iam_role_policy" "ecr_repository_access" {
  name = "ECRRepositoryAccess"
  role = aws_iam_role.healthomics_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories",
          "ecr:DescribeImages",
          "ecr:ListImages"
        ]
        Resource = aws_ecr_repository.simplefold_repo.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      }
    ]
  })
}

# Custom CloudWatch Logs policy for HealthOmics workflow logs
resource "aws_iam_role_policy" "cloudwatch_logs_access" {
  name = "CloudWatchLogsAccess"
  role = aws_iam_role.healthomics_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/omics/WorkflowLog*",
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/omics/WorkflowLog*:*"
        ]
      }
    ]
  })
}

# Custom HealthOmics policy with minimal required permissions
resource "aws_iam_role_policy" "omics_workflow_access" {
  name = "OmicsWorkflowAccess"
  role = aws_iam_role.healthomics_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "omics:GetWorkflow",
          "omics:StartRun",
          "omics:GetRun",
          "omics:ListRuns",
          "omics:CancelRun",
          "omics:GetRunTask",
          "omics:ListRunTasks"
        ]
        Resource = [
          "arn:aws:omics:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:workflow/*",
          "arn:aws:omics:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:run/*"
        ]
      }
    ]
  })
}

# Note: ECR access policy has been consolidated into ecr_repository_access above

# Create Nextflow config from template
resource "local_file" "nextflow_config" {
  filename = "${path.root}/../workflow/nextflow.config"
  content = templatefile("${path.root}/../workflow/nextflow.config.tpl", {
    S3_BUCKET_NAME     = aws_s3_bucket.simplefold_bucket.bucket
    ECR_URI            = "${aws_ecr_repository.simplefold_repo.repository_url}:latest"
    ECR_REGISTRY       = aws_ecr_repository.simplefold_repo.registry_id
    AWS_REGION         = data.aws_region.current.name
    EXECUTION_ROLE_ARN = aws_iam_role.healthomics_execution_role.arn
    AUTHOR_NAME        = var.author_name
  })


  depends_on = [
    aws_s3_bucket.simplefold_bucket,
    aws_ecr_repository.simplefold_repo,
    aws_iam_role.healthomics_execution_role
  ]
}

# Create archive of workflow files
data "archive_file" "workflow_zip" {
  type        = "zip"
  source_dir  = "${path.root}/../workflow"
  output_path = "${path.root}/simplefold-workflow.zip"
  excludes    = ["nextflow.config.tpl"]

  // Recreate if the zip contents change
  depends_on = [local_file.nextflow_config]
}

# Create a sample workflow definition ZIP file
resource "aws_s3_object" "workflow_definition" {
  bucket = aws_s3_bucket.simplefold_bucket.id
  key    = "workflows/simplefold-workflow.zip"
  source = "${path.module}/simplefold-workflow.zip"
  etag   = data.archive_file.workflow_zip.output_md5

  depends_on = [
    data.archive_file.workflow_zip,
    local_file.nextflow_config
  ]
}

# Upload test fasta file to S3
resource "aws_s3_object" "test_data" {
  bucket = aws_s3_bucket.simplefold_bucket.id
  key    = "input/rcsb_pdb_3J5R.fasta"
  source = "${path.root}/../input/rcsb_pdb_3J5R.fasta"
}

# Create HealthOmics workflow using awscc provider
resource "awscc_omics_workflow" "simplefold_workflow" {
  name        = var.workflow_name
  description = "SimpleFold protein structure prediction workflow"
  engine      = "NEXTFLOW"

  definition_uri = "s3://${aws_s3_bucket.simplefold_bucket.bucket}/${aws_s3_object.workflow_definition.key}"
  main           = "main.nf"

  storage_capacity = var.storage_capacity

  tags = {
    Name        = var.workflow_name
    Project     = var.project_name
    Environment = var.environment
    WorkflowHash = data.archive_file.workflow_zip.output_md5
  }

  lifecycle {
    replace_triggered_by = [
      aws_s3_object.workflow_definition
    ]
  }

  depends_on = [
    aws_s3_object.workflow_definition,
    data.archive_file.workflow_zip,
    local_file.nextflow_config
  ]
}
