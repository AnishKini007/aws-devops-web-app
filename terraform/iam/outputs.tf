# ========================================
# IAM Module Outputs
# ========================================

# Jenkins Service Account
output "jenkins_role_arn" {
  description = "ARN of IAM role for Jenkins service account"
  value       = aws_iam_role.jenkins.arn
}

output "jenkins_role_name" {
  description = "Name of IAM role for Jenkins service account"
  value       = aws_iam_role.jenkins.name
}

# Application Service Account
output "app_role_arn" {
  description = "ARN of IAM role for application service account"
  value       = aws_iam_role.app.arn
}

output "app_role_name" {
  description = "Name of IAM role for application service account"
  value       = aws_iam_role.app.name
}

# AWS Load Balancer Controller
output "lb_controller_role_arn" {
  description = "ARN of IAM role for AWS Load Balancer Controller"
  value       = aws_iam_role.lb_controller.arn
}

output "lb_controller_role_name" {
  description = "Name of IAM role for AWS Load Balancer Controller"
  value       = aws_iam_role.lb_controller.name
}
