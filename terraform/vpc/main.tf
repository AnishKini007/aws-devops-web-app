# ========================================
# VPC Module - Networking Foundation
# ========================================
# This module creates a production-ready VPC with:
# - Public subnets (for Load Balancers, NAT Gateways)
# - Private subnets (for EKS worker nodes, Jenkins, applications)
# - High availability across multiple AZs
# - Internet Gateway for public subnet internet access
# - NAT Gateways for private subnet outbound traffic

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
# VPC - Main Network Container
# ========================================
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  # DNS support is critical for EKS
  # EKS uses AWS DNS for service discovery
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Enable VPC flow logs for security auditing (optional but recommended)
  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-vpc"
      # Kubernetes cluster discovery tag
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }
  )
}

# ========================================
# Internet Gateway - Public Internet Access
# ========================================
# Enables resources in public subnets to communicate with the internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-igw"
    }
  )
}

# ========================================
# Public Subnets - For Load Balancers & NAT
# ========================================
# Public subnets host:
# - Application Load Balancers (Jenkins UI, App UI)
# - NAT Gateways (for private subnet internet access)
# - Bastion hosts (if needed for troubleshooting)

resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-public-subnet-${var.availability_zones[count.index]}"
      Type = "public"
      # EKS Load Balancer Controller uses this tag to place public LBs
      "kubernetes.io/role/elb" = "1"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }
  )
}

# ========================================
# Private Subnets - For EKS Worker Nodes
# ========================================
# Private subnets host:
# - EKS worker nodes (EC2 instances)
# - Jenkins pods
# - Application pods
# - Databases (if deployed in-cluster)

resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-private-subnet-${var.availability_zones[count.index]}"
      Type = "private"
      # EKS Load Balancer Controller uses this tag to place internal LBs
      "kubernetes.io/role/internal-elb" = "1"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }
  )
}

# ========================================
# Elastic IPs - For NAT Gateways
# ========================================
# Each NAT Gateway needs a static public IP
resource "aws_eip" "nat" {
  count = length(var.availability_zones)

  domain = "vpc"

  # Ensure IGW exists before creating EIP
  depends_on = [aws_internet_gateway.main]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-eip-nat-${var.availability_zones[count.index]}"
    }
  )
}

# ========================================
# NAT Gateways - Outbound Internet for Private Subnets
# ========================================
# NAT Gateways allow private subnet resources to:
# - Pull Docker images from DockerHub/ECR
# - Access AWS APIs (ECR, S3, etc.)
# - Download packages and dependencies
# Best practice: One NAT Gateway per AZ for high availability

resource "aws_nat_gateway" "main" {
  count = length(var.availability_zones)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-nat-${var.availability_zones[count.index]}"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# ========================================
# Route Table - Public Subnets
# ========================================
# Public subnets route all traffic to Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-public-rt"
      Type = "public"
    }
  )
}

# Default route to Internet Gateway
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ========================================
# Route Tables - Private Subnets
# ========================================
# Each private subnet gets its own route table pointing to its AZ's NAT Gateway
# This ensures if one NAT Gateway fails, only one AZ is affected

resource "aws_route_table" "private" {
  count = length(var.availability_zones)

  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-private-rt-${var.availability_zones[count.index]}"
      Type = "private"
    }
  )
}

# Route to NAT Gateway for each private subnet
resource "aws_route" "private_nat_gateway" {
  count = length(var.availability_zones)

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[count.index].id
}

# Associate private subnets with their respective route tables
resource "aws_route_table_association" "private" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ========================================
# VPC Endpoints - Cost Optimization (Optional)
# ========================================
# VPC endpoints allow private subnet resources to access AWS services
# without going through NAT Gateway (reduces NAT Gateway data transfer costs)

# S3 Gateway Endpoint (Free)
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.s3"

  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private[*].id
  )

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-s3-endpoint"
    }
  )
}

# ECR API Endpoint (reduces NAT costs for pulling images)
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = aws_subnet.private[*].id

  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-ecr-api-endpoint"
    }
  )
}

# ECR Docker Endpoint (reduces NAT costs for pulling images)
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = aws_subnet.private[*].id

  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-ecr-dkr-endpoint"
    }
  )
}

# ========================================
# Security Group - VPC Endpoints
# ========================================
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.project_name}-vpc-endpoints-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.main.id

  # Allow HTTPS traffic from VPC CIDR
  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-vpc-endpoints-sg"
    }
  )
}
