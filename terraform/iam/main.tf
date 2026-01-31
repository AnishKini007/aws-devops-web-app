# ========================================
# IAM Module - Service Accounts for Kubernetes
# ========================================
# This module creates IAM roles for Kubernetes service accounts using IRSA:
# - Jenkins service account (push to ECR, deploy to EKS)
# - Application service account (read from S3, write logs, etc.)
# - AWS Load Balancer Controller service account

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ========================================
# Data Sources
# ========================================
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

# ========================================
# Jenkins Service Account IAM Role
# ========================================
# Jenkins needs permissions to:
# - Push/pull images to/from ECR
# - Deploy applications to EKS
# - Access AWS resources (S3, SSM for secrets)

resource "aws_iam_role" "jenkins" {
  name               = "${var.cluster_name}-jenkins-sa-role"
  assume_role_policy = data.aws_iam_policy_document.jenkins_assume_role.json

  tags = merge(
    var.common_tags,
    {
      Name                                                    = "${var.cluster_name}-jenkins-sa-role"
      "kubernetes.io/service-account/name"                    = "jenkins"
      "kubernetes.io/service-account/namespace"               = var.jenkins_namespace
    }
  )
}

data "aws_iam_policy_document" "jenkins_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.jenkins_namespace}:jenkins"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# Jenkins ECR Policy - Push and pull images
resource "aws_iam_policy" "jenkins_ecr" {
  name        = "${var.cluster_name}-jenkins-ecr-policy"
  description = "Policy for Jenkins to push/pull images to/from ECR"
  policy      = data.aws_iam_policy_document.jenkins_ecr.json

  tags = merge(
    var.common_tags,
    {
      Name = "${var.cluster_name}-jenkins-ecr-policy"
    }
  )
}

data "aws_iam_policy_document" "jenkins_ecr" {
  # Get ECR authorization token
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }

  # Push and pull images
  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages"
    ]
    resources = var.ecr_repository_arns
  }
}

resource "aws_iam_role_policy_attachment" "jenkins_ecr" {
  policy_arn = aws_iam_policy.jenkins_ecr.arn
  role       = aws_iam_role.jenkins.name
}

# Jenkins EKS Policy - Deploy to Kubernetes
resource "aws_iam_policy" "jenkins_eks" {
  name        = "${var.cluster_name}-jenkins-eks-policy"
  description = "Policy for Jenkins to interact with EKS"
  policy      = data.aws_iam_policy_document.jenkins_eks.json

  tags = merge(
    var.common_tags,
    {
      Name = "${var.cluster_name}-jenkins-eks-policy"
    }
  )
}

data "aws_iam_policy_document" "jenkins_eks" {
  # Describe EKS cluster
  statement {
    effect = "Allow"
    actions = [
      "eks:DescribeCluster",
      "eks:ListClusters"
    ]
    resources = [var.cluster_arn]
  }
}

resource "aws_iam_role_policy_attachment" "jenkins_eks" {
  policy_arn = aws_iam_policy.jenkins_eks.arn
  role       = aws_iam_role.jenkins.name
}

# Jenkins SSM Policy - Access secrets from Parameter Store
resource "aws_iam_policy" "jenkins_ssm" {
  name        = "${var.cluster_name}-jenkins-ssm-policy"
  description = "Policy for Jenkins to access SSM Parameter Store"
  policy      = data.aws_iam_policy_document.jenkins_ssm.json

  tags = merge(
    var.common_tags,
    {
      Name = "${var.cluster_name}-jenkins-ssm-policy"
    }
  )
}

data "aws_iam_policy_document" "jenkins_ssm" {
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${var.cluster_name}/jenkins/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "ssm:DescribeParameters"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy_attachment" "jenkins_ssm" {
  policy_arn = aws_iam_policy.jenkins_ssm.arn
  role       = aws_iam_role.jenkins.name
}

# ========================================
# Application Service Account IAM Role
# ========================================
# Application pods may need permissions to:
# - Read from S3
# - Write logs to CloudWatch
# - Access other AWS services

resource "aws_iam_role" "app" {
  name               = "${var.cluster_name}-app-sa-role"
  assume_role_policy = data.aws_iam_policy_document.app_assume_role.json

  tags = merge(
    var.common_tags,
    {
      Name                                                    = "${var.cluster_name}-app-sa-role"
      "kubernetes.io/service-account/name"                    = var.app_service_account_name
      "kubernetes.io/service-account/namespace"               = var.app_namespace
    }
  )
}

data "aws_iam_policy_document" "app_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.app_namespace}:${var.app_service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# Application S3 Policy (example)
resource "aws_iam_policy" "app_s3" {
  count = var.create_app_s3_policy ? 1 : 0

  name        = "${var.cluster_name}-app-s3-policy"
  description = "Policy for application to access S3"
  policy      = data.aws_iam_policy_document.app_s3[0].json

  tags = merge(
    var.common_tags,
    {
      Name = "${var.cluster_name}-app-s3-policy"
    }
  )
}

data "aws_iam_policy_document" "app_s3" {
  count = var.create_app_s3_policy ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::${var.cluster_name}-app-data",
      "arn:${data.aws_partition.current.partition}:s3:::${var.cluster_name}-app-data/*"
    ]
  }
}

resource "aws_iam_role_policy_attachment" "app_s3" {
  count = var.create_app_s3_policy ? 1 : 0

  policy_arn = aws_iam_policy.app_s3[0].arn
  role       = aws_iam_role.app.name
}

# ========================================
# AWS Load Balancer Controller IAM Role
# ========================================
# LB Controller creates ALB/NLB for Kubernetes Ingress/Service resources

resource "aws_iam_role" "lb_controller" {
  name               = "${var.cluster_name}-lb-controller-role"
  assume_role_policy = data.aws_iam_policy_document.lb_controller_assume_role.json

  tags = merge(
    var.common_tags,
    {
      Name                                                    = "${var.cluster_name}-lb-controller-role"
      "kubernetes.io/service-account/name"                    = "aws-load-balancer-controller"
      "kubernetes.io/service-account/namespace"               = "kube-system"
    }
  )
}

data "aws_iam_policy_document" "lb_controller_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# AWS Load Balancer Controller Policy
# Source: https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
resource "aws_iam_policy" "lb_controller" {
  name        = "${var.cluster_name}-lb-controller-policy"
  description = "Policy for AWS Load Balancer Controller"
  policy      = file("${path.module}/lb_controller_iam_policy.json")

  tags = merge(
    var.common_tags,
    {
      Name = "${var.cluster_name}-lb-controller-policy"
    }
  )
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  policy_arn = aws_iam_policy.lb_controller.arn
  role       = aws_iam_role.lb_controller.name
}
