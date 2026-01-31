# ========================================
# Root Module Outputs
# ========================================

# VPC Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs for EKS"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs for Load Balancers"
  value       = module.vpc.public_subnet_ids
}

# EKS Outputs
output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = module.eks.cluster_version
}

output "eks_oidc_provider_arn" {
  description = "ARN of the OIDC Provider for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

# ECR Outputs
output "ecr_repository_url" {
  description = "ECR repository URL for application images"
  value       = module.ecr.app_repository_url
}

output "ecr_repository_name" {
  description = "ECR repository name"
  value       = module.ecr.app_repository_name
}

# IAM Outputs
output "jenkins_role_arn" {
  description = "IAM role ARN for Jenkins service account"
  value       = module.iam.jenkins_role_arn
}

output "lb_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = module.iam.lb_controller_role_arn
}

output "app_role_arn" {
  description = "IAM role ARN for application service account"
  value       = module.iam.app_role_arn
}
