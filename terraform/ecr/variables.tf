# ========================================
# ECR Module Variables
# ========================================

variable "app_repository_name" {
  description = "Name of the ECR repository for application images"
  type        = string
  default     = "eks-cicd-app"
}

variable "create_jenkins_agent_repo" {
  description = "Whether to create a separate ECR repository for Jenkins agents"
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
