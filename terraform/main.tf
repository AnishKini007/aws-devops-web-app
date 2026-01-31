# ========================================
# Root Terraform Configuration
# ========================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

# ========================================
# AWS Provider Configuration
# ========================================
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# ========================================
# VPC Module
# ========================================
module "vpc" {
  source = "./vpc"

  aws_region         = var.aws_region
  project_name       = var.project_name
  cluster_name       = var.cluster_name
  availability_zones = ["${var.aws_region}a", "${var.aws_region}b"]

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ========================================
# EKS Module
# ========================================
module "eks" {
  source = "./eks"

  cluster_name       = var.cluster_name
  kubernetes_version = "1.31"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  # API Server Access
  enable_public_access     = true
  api_public_access_cidrs  = ["0.0.0.0/0"] # TODO: Restrict to your IP

  # Node Group Configuration
  node_instance_types = ["t3.medium"]
  node_desired_size   = 2
  node_min_size       = 1
  node_max_size       = 4
  node_disk_size      = 30

  environment = var.environment
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  depends_on = [module.vpc]
}

# ========================================
# ECR Module
# ========================================
module "ecr" {
  source = "./ecr"

  app_repository_name       = "${var.project_name}-app"
  create_jenkins_agent_repo = false

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ========================================
# IAM Module
# ========================================
module "iam" {
  source = "./iam"

  cluster_name       = var.cluster_name
  cluster_arn        = module.eks.cluster_arn
  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_provider_url  = module.eks.cluster_oidc_issuer_url
  ecr_repository_arns = [module.ecr.app_repository_arn]

  # Jenkins configuration
  jenkins_namespace = "jenkins"

  # Application configuration
  app_namespace           = "default"
  app_service_account_name = "app-sa"
  create_app_s3_policy    = false

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  depends_on = [module.eks, module.ecr]
}
