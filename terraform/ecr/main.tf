# ========================================
# ECR Module - Private Docker Registry
# ========================================
# Amazon ECR (Elastic Container Registry) provides:
# - Private Docker image storage
# - Integration with EKS (no additional auth needed with IRSA)
# - Image scanning for vulnerabilities
# - Lifecycle policies for cost optimization

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ========================================
# ECR Repository for Application Images
# ========================================
resource "aws_ecr_repository" "app" {
  name                 = var.app_repository_name
  image_tag_mutability = "MUTABLE" # Allow tag overwrites for dev, use IMMUTABLE for prod

  # Scan images on push for security vulnerabilities
  image_scanning_configuration {
    scan_on_push = true
  }

  # Encryption at rest using AWS managed KMS key
  encryption_configuration {
    encryption_type = "AES256" # Use "KMS" with kms_key for customer-managed keys
  }

  tags = merge(
    var.common_tags,
    {
      Name        = var.app_repository_name
      Purpose     = "Application Docker images"
      ManagedBy   = "Terraform"
    }
  )
}

# ========================================
# ECR Repository for Jenkins Agent Images (Optional)
# ========================================
# Separate repository for custom Jenkins agent images
resource "aws_ecr_repository" "jenkins_agent" {
  count = var.create_jenkins_agent_repo ? 1 : 0

  name                 = "${var.app_repository_name}-jenkins-agent"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.app_repository_name}-jenkins-agent"
      Purpose     = "Jenkins agent Docker images"
      ManagedBy   = "Terraform"
    }
  )
}

# ========================================
# ECR Lifecycle Policy - Cost Optimization
# ========================================
# Automatically delete old/untagged images to reduce storage costs
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "release", "prod"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last 5 dev/staging images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["dev", "staging", "latest"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 3
        description  = "Delete untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ========================================
# ECR Repository Policy - Cross-Account Access (Optional)
# ========================================
# Allow specific AWS accounts or services to pull images
# Uncomment if you need cross-account access

# resource "aws_ecr_repository_policy" "app" {
#   repository = aws_ecr_repository.app.name
#
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid    = "AllowCrossAccountPull"
#         Effect = "Allow"
#         Principal = {
#           AWS = [
#             "arn:aws:iam::ACCOUNT_ID:root"
#           ]
#         }
#         Action = [
#           "ecr:GetDownloadUrlForLayer",
#           "ecr:BatchGetImage",
#           "ecr:BatchCheckLayerAvailability"
#         ]
#       }
#     ]
#   })
# }
