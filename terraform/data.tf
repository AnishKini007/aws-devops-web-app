# AWS Account ID output (useful for scripts)
output "account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

data "aws_caller_identity" "current" {}
