# ========================================
# ECR Module Outputs
# ========================================

output "app_repository_url" {
  description = "URL of the ECR repository for application images"
  value       = aws_ecr_repository.app.repository_url
}

output "app_repository_arn" {
  description = "ARN of the ECR repository for application"
  value       = aws_ecr_repository.app.arn
}

output "app_repository_name" {
  description = "Name of the ECR repository for application"
  value       = aws_ecr_repository.app.name
}

output "jenkins_agent_repository_url" {
  description = "URL of the ECR repository for Jenkins agent images"
  value       = var.create_jenkins_agent_repo ? aws_ecr_repository.jenkins_agent[0].repository_url : ""
}

output "registry_id" {
  description = "Registry ID (AWS Account ID)"
  value       = aws_ecr_repository.app.registry_id
}
