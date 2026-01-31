# ========================================
# AWS Load Balancer Controller Setup Script
# ========================================
# This script installs AWS Load Balancer Controller on EKS
# It's required for ALB/NLB provisioning via Kubernetes Ingress

# Prerequisites:
# - EKS cluster is running
# - kubectl is configured
# - Helm is installed
# - IAM role for LB controller is created by Terraform

# Step 1: Get IAM role ARN from Terraform
Write-Host "Getting IAM role ARN for AWS Load Balancer Controller..." -ForegroundColor Cyan
Set-Location terraform
$LB_ROLE_ARN = terraform output -raw lb_controller_role_arn
Write-Host "IAM Role ARN: $LB_ROLE_ARN" -ForegroundColor Green
Set-Location ..

# Step 2: Add EKS Helm repository
Write-Host "Adding EKS Helm repository..." -ForegroundColor Cyan
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Step 3: Create service account with IRSA annotation
Write-Host "Creating service account for AWS Load Balancer Controller..." -ForegroundColor Cyan
@"
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: $LB_ROLE_ARN
  labels:
    app.kubernetes.io/name: aws-load-balancer-controller
    app.kubernetes.io/component: controller
"@ | kubectl apply -f -

# Step 4: Install AWS Load Balancer Controller
Write-Host "Installing AWS Load Balancer Controller..." -ForegroundColor Cyan
$CLUSTER_NAME = "eks-cicd-cluster"
$REGION = "ap-south-1"
$VPC_ID = "vpc-061bb63fb88d11e15"

helm install aws-load-balancer-controller eks/aws-load-balancer-controller `
  --namespace kube-system `
  --set clusterName=$CLUSTER_NAME `
  --set serviceAccount.create=false `
  --set serviceAccount.name=aws-load-balancer-controller `
  --set region=$REGION `
  --set vpcId=$VPC_ID `
  --wait

# Step 5: Verify installation
Write-Host "`nVerifying AWS Load Balancer Controller installation..." -ForegroundColor Cyan
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

Write-Host "`n✅ AWS Load Balancer Controller installed successfully!" -ForegroundColor Green
Write-Host "You can now create Ingress resources with kubernetes.io/ingress.class: alb" -ForegroundColor Yellow
