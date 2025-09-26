# © 2025 BioTeam, LLC All rights reserved.
# SimpleFold Makefile
# Automates Docker build, ECR operations, and AWS HealthOmics workflow management

.PHONY: help build login push deploy run clean

# Default target
help:
	@echo "SimpleFold Make Commands:"
	@echo ""
	@echo "  make build    - Build Docker container for linux/amd64"
	@echo "  make login    - Login to ECR registry"
	@echo "  make push     - Push container to ECR"
	@echo "  make deploy   - Build, login, and push (complete deployment)"
	@echo "  make run      - Start AWS HealthOmics workflow run"
	@echo "  make clean    - Remove local Docker images"
	@echo ""
	@echo "Prerequisites:"
	@echo "  - Run 'terraform apply' in terraform/ directory first"
	@echo "  - Ensure AWS CLI is configured"

# Get Terraform outputs
ECR_URL := $(shell cd terraform && terraform output -raw ecr_repository_url 2>/dev/null)
AWS_REGION := $(shell cd terraform && terraform output -raw aws_region 2>/dev/null)
S3_BUCKET := $(shell cd terraform && terraform output -raw s3_bucket_name 2>/dev/null)
EXECUTION_ROLE_ARN := $(shell cd terraform && terraform output -raw execution_role_arn 2>/dev/null)
WORKFLOW_ID := $(shell cd terraform && terraform output -raw workflow_id 2>/dev/null)

# Build Docker container
build:
	@echo "Building SimpleFold Docker container..."
	@if [ -z "$(ECR_URL)" ]; then \
		echo "Error: ECR repository URL not found. Run 'terraform apply' first."; \
		exit 1; \
	fi
	docker build --platform=linux/amd64 -t $(ECR_URL):latest .

# Login to ECR
login:
	@echo "Logging into ECR..."
	@if [ -z "$(AWS_REGION)" ] || [ -z "$(ECR_URL)" ]; then \
		echo "Error: AWS region or ECR URL not found. Run 'terraform apply' first."; \
		exit 1; \
	fi
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(ECR_URL)

# Push container to ECR
push:
	@echo "Pushing container to ECR..."
	@if [ -z "$(ECR_URL)" ]; then \
		echo "Error: ECR repository URL not found. Run 'terraform apply' first."; \
		exit 1; \
	fi
	docker push $(ECR_URL):latest

# Complete deployment: build, login, and push
deploy-container: build login push
	@echo "✅ SimpleFold container successfully deployed to ECR!"

# Start HealthOmics workflow run
run:
	@echo "Starting AWS HealthOmics workflow run..."
	@if [ -z "$(EXECUTION_ROLE_ARN)" ] || [ -z "$(S3_BUCKET)" ] || [ -z "$(WORKFLOW_ID)" ]; then \
		echo "Error: Missing Terraform outputs. Run 'terraform apply' first."; \
		exit 1; \
	fi
	@RUN_NAME="simplefold-run-$$(date +%Y%m%d-%H%M%S)"; \
	echo "Starting run: $$RUN_NAME"; \
	aws omics start-run \
		--role-arn "$(EXECUTION_ROLE_ARN)" \
		--output-uri "s3://$(S3_BUCKET)/out/" \
		--parameters "{\"input_dir\": \"s3://$(S3_BUCKET)/input/\"}" \
		--workflow-id "$(WORKFLOW_ID)" \
		--name "$$RUN_NAME"

# Clean up local Docker images
clean:
	@echo "Cleaning up local Docker images..."
	-docker rmi $(ECR_URL):latest 2>/dev/null || echo "No images to remove"
	-docker image prune -f

# Check Terraform outputs
check-terraform:
	@echo "Checking Terraform outputs..."
	@cd terraform && terraform output 2>/dev/null || echo "Run 'terraform apply' first"