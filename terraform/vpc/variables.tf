# ========================================
# VPC Module Variables
# ========================================

variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "eks-cicd"
}

variable "cluster_name" {
  description = "EKS cluster name for tagging"
  type        = string
  default     = "eks-cicd-cluster"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC - allows up to 65,536 IP addresses"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones for high availability (minimum 2 for EKS)"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (256 IPs each)"
  type        = list(string)
  default = [
    "10.0.1.0/24",  # ap-south-1a public
    "10.0.2.0/24",  # ap-south-1b public
  ]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (1024 IPs each for pod networking)"
  type        = list(string)
  default = [
    "10.0.8.0/22",  # ap-south-1a private (10.0.8.0 - 10.0.11.255)
    "10.0.12.0/22",  # ap-south-1b private (10.0.12.0 - 10.0.15.255)
  ]
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Project     = "EKS-CICD"
    ManagedBy   = "Terraform"
    Environment = "production"
  }
}
