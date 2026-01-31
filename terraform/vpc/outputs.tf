# ========================================
# VPC Module Outputs
# ========================================
# These outputs are consumed by other Terraform modules (EKS, etc.)

output "vpc_id" {
  description = "VPC ID for use in security groups and other resources"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block for security group rules"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs for Load Balancers"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs for EKS worker nodes"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs for monitoring and troubleshooting"
  value       = aws_nat_gateway.main[*].id
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}

output "availability_zones" {
  description = "Availability zones used"
  value       = var.availability_zones
}
