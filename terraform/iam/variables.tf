# ========================================
# IAM Module Variables
# ========================================

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_arn" {
  description = "EKS cluster ARN"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the OIDC provider"
  type        = string
}

variable "ecr_repository_arns" {
  description = "List of ECR repository ARNs that Jenkins can access"
  type        = list(string)
  default     = []
}

# ========================================
# Jenkins Service Account Variables
# ========================================

variable "jenkins_namespace" {
  description = "Kubernetes namespace where Jenkins will be deployed"
  type        = string
  default     = "jenkins"
}

# ========================================
# Application Service Account Variables
# ========================================

variable "app_namespace" {
  description = "Kubernetes namespace where application will be deployed"
  type        = string
  default     = "default"
}

variable "app_service_account_name" {
  description = "Name of the Kubernetes service account for application"
  type        = string
  default     = "app-sa"
}

variable "create_app_s3_policy" {
  description = "Whether to create S3 access policy for application"
  type        = bool
  default     = false
}

# ========================================
# Common Variables
# ========================================

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
