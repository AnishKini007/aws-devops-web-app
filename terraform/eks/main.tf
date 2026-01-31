# ========================================
# EKS Cluster Module
# ========================================
# This module creates a production-ready EKS cluster with:
# - Managed node groups for worker nodes
# - IRSA (IAM Roles for Service Accounts) for pod-level permissions
# - EKS add-ons for networking and storage
# - Security groups with least-privilege access
# - CloudWatch logging for audit and diagnostics

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# ========================================
# Data Sources
# ========================================

# Get current AWS account ID and caller identity
data "aws_caller_identity" "current" {}

# Get current AWS partition (aws, aws-cn, aws-us-gov)
data "aws_partition" "current" {}

# ========================================
# EKS Cluster
# ========================================
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    # Deploy EKS control plane across private subnets for security
    subnet_ids = var.private_subnet_ids

    # Disable public access to API server for production
    # Set to true initially for easier setup, then disable after configuring VPN/bastion
    endpoint_private_access = true
    endpoint_public_access  = var.enable_public_access

    # Restrict public API access to specific CIDR blocks (your office/home IP)
    public_access_cidrs = var.api_public_access_cidrs

    # Security group for EKS control plane
    security_group_ids = [aws_security_group.cluster.id]
  }

  # Enable control plane logging for security and troubleshooting
  enabled_cluster_log_types = [
    "api",              # Kubernetes API server logs
    "audit",            # Kubernetes audit logs
    "authenticator",    # AWS IAM authenticator logs
    "controllerManager", # Kubernetes controller manager logs
    "scheduler"         # Kubernetes scheduler logs
  ]

  # Encryption at rest for Kubernetes secrets
  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = aws_kms_key.eks.arn
    }
  }

  # Ensure IAM role and VPC resources exist before creating cluster
  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy_attachment.cluster_service_policy,
    aws_cloudwatch_log_group.cluster
  ]

  tags = merge(
    var.common_tags,
    {
      Name = var.cluster_name
    }
  )
}

# ========================================
# CloudWatch Log Group for EKS Logs
# ========================================
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 7 # Reduce to 7 days for cost savings (Free Tier: 5GB storage)

  tags = merge(
    var.common_tags,
    {
      Name = "${var.cluster_name}-logs"
    }
  )
}

# ========================================
# KMS Key for EKS Secrets Encryption
# ========================================
resource "aws_kms_key" "eks" {
  description             = "KMS key for EKS cluster ${var.cluster_name} secrets encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.cluster_name}-kms"
    }
  )
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.cluster_name}-eks"
  target_key_id = aws_kms_key.eks.key_id
}

# ========================================
# EKS Managed Node Group
# ========================================
# Managed node groups handle:
# - EC2 instance provisioning and lifecycle
# - Auto Scaling group management
# - Automatic security patches
# - Graceful node termination

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids

  # Instance types optimized for cost and performance
  # t3.medium: 2 vCPU, 4GB RAM - good for dev/staging
  # For production, consider t3.large or m5.large
  instance_types = var.node_instance_types

  # Disk size is configured in the launch template block_device_mappings
  # Cannot use disk_size when launch_template has block_device_mappings

  # Scaling configuration
  scaling_config {
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
    min_size     = var.node_min_size
  }

  # Update configuration - rolling updates
  update_config {
    max_unavailable_percentage = 33 # Update 1/3 of nodes at a time
  }

  # Launch template for advanced configuration
  launch_template {
    id      = aws_launch_template.node.id
    version = "$Latest"
  }

  # Labels applied to all nodes in this group
  labels = {
    role        = "general"
    environment = var.environment
  }

  # Kubernetes taints (none for general workloads)
  # Add taints if you want dedicated nodes for specific workloads

  # Ensure IAM role exists before creating node group
  depends_on = [
    aws_iam_role_policy_attachment.node_policy,
    aws_iam_role_policy_attachment.node_cni_policy,
    aws_iam_role_policy_attachment.node_ecr_policy,
    aws_iam_role_policy_attachment.node_ssm_policy
  ]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.cluster_name}-node-group"
    }
  )

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [scaling_config[0].desired_size]
  }
}

# ========================================
# Launch Template for Node Group
# ========================================
resource "aws_launch_template" "node" {
  name_prefix = "${var.cluster_name}-node-"
  description = "Launch template for EKS managed node group"

  # Block device mapping for root volume
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.node_disk_size
      volume_type           = "gp3" # GP3 is cheaper and faster than GP2
      iops                  = 3000
      throughput            = 125
      delete_on_termination = true
      encrypted             = true
    }
  }

  # Instance metadata service v2 (IMDSv2) for security
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Enforce IMDSv2
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  # Network interface configuration
  network_interfaces {
    associate_public_ip_address = false # Nodes in private subnet
    security_groups             = [aws_security_group.node.id]
    delete_on_termination       = true
  }

  # Note: user_data is not needed for EKS managed node groups
  # EKS automatically handles node bootstrap and registration

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      var.common_tags,
      {
        Name = "${var.cluster_name}-node"
      }
    )
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(
      var.common_tags,
      {
        Name = "${var.cluster_name}-node-volume"
      }
    )
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ========================================
# OIDC Provider for IRSA
# ========================================
# IRSA (IAM Roles for Service Accounts) allows Kubernetes pods
# to assume IAM roles without storing credentials

data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = merge(
    var.common_tags,
    {
      Name = "${var.cluster_name}-oidc"
    }
  )
}

# ========================================
# EKS Add-ons
# ========================================
# Add-ons are critical Kubernetes components managed by AWS

# VPC CNI - Provides pod networking using AWS VPC IPs
resource "aws_eks_addon" "vpc_cni" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "vpc-cni"
  addon_version            = var.vpc_cni_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # Use IRSA for VPC CNI
  service_account_role_arn = aws_iam_role.vpc_cni.arn

  tags = var.common_tags
}

# CoreDNS - DNS server for Kubernetes
resource "aws_eks_addon" "coredns" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "coredns"
  addon_version            = var.coredns_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.main]

  tags = var.common_tags
}

# kube-proxy - Network proxy for Kubernetes services
resource "aws_eks_addon" "kube_proxy" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "kube-proxy"
  addon_version            = var.kube_proxy_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.common_tags
}

# EBS CSI Driver - For persistent volumes using EBS
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = var.ebs_csi_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # Use IRSA for EBS CSI Driver
  service_account_role_arn = aws_iam_role.ebs_csi.arn

  # Wait for node group to be ready
  depends_on = [aws_eks_node_group.main]

  tags = var.common_tags
}
