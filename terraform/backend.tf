# ========================================
# Terraform Backend Configuration
# ========================================
# Backend stores Terraform state remotely for:
# - Team collaboration
# - State locking (prevents concurrent modifications)
# - State versioning and recovery
#
# SETUP INSTRUCTIONS:
# 1. Create S3 bucket: aws s3 mb s3://eks-cicd-terraform-state-<YOUR_ACCOUNT_ID>
# 2. Create DynamoDB table: aws dynamodb create-table \
#      --table-name eks-cicd-terraform-locks \
#      --attribute-definitions AttributeName=LockID,AttributeType=S \
#      --key-schema AttributeName=LockID,KeyType=HASH \
#      --billing-mode PAY_PER_REQUEST
# 3. Uncomment the backend block below
# 4. Run: terraform init

# Uncomment after creating S3 bucket and DynamoDB table
# terraform {
#   backend "s3" {
#     bucket         = "eks-cicd-terraform-state-<YOUR_ACCOUNT_ID>"
#     key            = "eks-cicd/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     dynamodb_table = "eks-cicd-terraform-locks"
#   }
# }

# For initial testing, local backend is used (default)
# State file will be stored in terraform.tfstate locally
