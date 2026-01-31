# ========================================
# EKS Module Variables
# ========================================

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.31" # Latest stable version as of Jan 2026
}

variable "vpc_id" {
  description = "VPC ID where EKS cluster will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EKS worker nodes"
  type        = list(string)
}

variable "enable_public_access" {
  description = "Enable public access to EKS API server"
  type        = bool
  default     = true # Set to false for production after configuring VPN/bastion
}

variable "api_public_access_cidrs" {
  description = "CIDR blocks allowed to access EKS API server publicly"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict to your IP in production
}

# ========================================
# Node Group Variables
# ========================================

variable "node_instance_types" {
  description = "EC2 instance types for worker nodes"
  type        = list(string)
  default     = ["t3.medium"] # 2 vCPU, 4GB RAM - adjust for production
}

variable "node_disk_size" {
  description = "Disk size in GB for worker nodes"
  type        = number
  default     = 30
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
}

# ========================================
# EKS Add-on Versions
# ========================================
# These versions are compatible with Kubernetes 1.31
# Check latest versions: aws eks describe-addon-versions --kubernetes-version 1.31

variable "vpc_cni_version" {
  description = "VPC CNI add-on version"
  type        = string
  default     = "v1.18.5-eksbuild.1" # Latest for K8s 1.31
}

variable "coredns_version" {
  description = "CoreDNS add-on version"
  type        = string
  default     = "v1.11.3-eksbuild.2" # Latest for K8s 1.31
}

variable "kube_proxy_version" {
  description = "kube-proxy add-on version"
  type        = string
  default     = "v1.31.2-eksbuild.3" # Latest for K8s 1.31
}

variable "ebs_csi_version" {
  description = "EBS CSI driver add-on version"
  type        = string
  default     = "v1.36.0-eksbuild.1" # Latest for K8s 1.31
}

# ========================================
# Common Variables
# ========================================

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
