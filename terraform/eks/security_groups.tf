# ========================================
# Security Groups for EKS
# ========================================

# ========================================
# EKS Cluster Security Group
# ========================================
# Controls network access to the EKS control plane
resource "aws_security_group" "cluster" {
  name_prefix = "${var.cluster_name}-cluster-sg-"
  description = "Security group for EKS cluster control plane"
  vpc_id      = var.vpc_id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.cluster_name}-cluster-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Allow egress from control plane to worker nodes
resource "aws_security_group_rule" "cluster_egress_to_nodes" {
  description              = "Allow control plane to communicate with worker nodes"
  type                     = "egress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node.id
}

# Allow egress to worker nodes on port 443 (for webhooks)
resource "aws_security_group_rule" "cluster_egress_to_nodes_443" {
  description              = "Allow control plane to communicate with worker nodes on HTTPS"
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node.id
}

# Allow all egress for DNS, metrics, logs
resource "aws_security_group_rule" "cluster_egress_all" {
  description       = "Allow all outbound traffic from control plane"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.cluster.id
  cidr_blocks       = ["0.0.0.0/0"]
}

# ========================================
# EKS Node Security Group
# ========================================
# Controls network access to worker nodes
resource "aws_security_group" "node" {
  name_prefix = "${var.cluster_name}-node-sg-"
  description = "Security group for EKS worker nodes"
  vpc_id      = var.vpc_id

  tags = merge(
    var.common_tags,
    {
      Name                                        = "${var.cluster_name}-node-sg"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Allow nodes to communicate with each other
resource "aws_security_group_rule" "node_ingress_self" {
  description       = "Allow nodes to communicate with each other"
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  security_group_id = aws_security_group.node.id
  self              = true
}

# Allow worker Kubelets and pods to receive communication from control plane
resource "aws_security_group_rule" "node_ingress_cluster" {
  description              = "Allow worker nodes to receive communication from control plane"
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.cluster.id
}

# Allow pods running extension API servers on port 443 to receive communication from control plane
resource "aws_security_group_rule" "node_ingress_cluster_443" {
  description              = "Allow pods running extension API servers to receive communication from control plane"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.cluster.id
}

# Allow all egress from nodes
resource "aws_security_group_rule" "node_egress_all" {
  description       = "Allow all outbound traffic from worker nodes"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.node.id
  cidr_blocks       = ["0.0.0.0/0"]
}

# Additional rule to allow control plane to connect to nodes on port 443 (recommended)
resource "aws_security_group_rule" "cluster_ingress_nodes_443" {
  description              = "Allow pods to communicate with the cluster API Server"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node.id
}
