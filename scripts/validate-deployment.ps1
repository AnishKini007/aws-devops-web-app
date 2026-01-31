# ========================================
# Deployment Validation Script
# ========================================
# This script validates the entire infrastructure deployment

param(
    [Parameter(Mandatory=$false)]
    [string]$Region = "ap-south-1",
    
    [Parameter(Mandatory=$false)]
    [string]$ClusterName = "eks-cicd-cluster"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "EKS CI/CD Platform Validation" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Test 1: Check AWS CLI
Write-Host "[1/10] Checking AWS CLI..." -ForegroundColor Yellow
try {
    $awsVersion = aws --version
    Write-Host "✅ AWS CLI installed: $awsVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ AWS CLI not found. Please install it." -ForegroundColor Red
    exit 1
}

# Test 2: Check kubectl
Write-Host "`n[2/10] Checking kubectl..." -ForegroundColor Yellow
try {
    $kubectlVersion = kubectl version --client --short
    Write-Host "✅ kubectl installed: $kubectlVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ kubectl not found. Please install it." -ForegroundColor Red
    exit 1
}

# Test 3: Check Helm
Write-Host "`n[3/10] Checking Helm..." -ForegroundColor Yellow
try {
    $helmVersion = helm version --short
    Write-Host "✅ Helm installed: $helmVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Helm not found. Please install it." -ForegroundColor Red
    exit 1
}

# Test 4: Check Terraform state
Write-Host "`n[4/10] Checking Terraform deployment..." -ForegroundColor Yellow
Set-Location terraform
try {
    $tfState = terraform show -json | ConvertFrom-Json
    if ($tfState) {
        Write-Host "✅ Terraform state found" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️  Terraform state not found or not initialized" -ForegroundColor Yellow
}
Set-Location ..

# Test 5: Check EKS cluster
Write-Host "`n[5/10] Checking EKS cluster..." -ForegroundColor Yellow
try {
    aws eks update-kubeconfig --region $Region --name $ClusterName 2>$null
    $clusterInfo = kubectl cluster-info
    Write-Host "✅ EKS cluster accessible" -ForegroundColor Green
} catch {
    Write-Host "❌ Cannot access EKS cluster" -ForegroundColor Red
    exit 1
}

# Test 6: Check nodes
Write-Host "`n[6/10] Checking EKS nodes..." -ForegroundColor Yellow
$nodes = kubectl get nodes --no-headers | Measure-Object
if ($nodes.Count -gt 0) {
    Write-Host "✅ Found $($nodes.Count) node(s)" -ForegroundColor Green
    kubectl get nodes
} else {
    Write-Host "❌ No nodes found" -ForegroundColor Red
}

# Test 7: Check AWS Load Balancer Controller
Write-Host "`n[7/10] Checking AWS Load Balancer Controller..." -ForegroundColor Yellow
$lbController = kubectl get deployment -n kube-system aws-load-balancer-controller --no-headers 2>$null
if ($lbController) {
    Write-Host "✅ AWS Load Balancer Controller deployed" -ForegroundColor Green
} else {
    Write-Host "⚠️  AWS Load Balancer Controller not found" -ForegroundColor Yellow
}

# Test 8: Check Jenkins deployment
Write-Host "`n[8/10] Checking Jenkins..." -ForegroundColor Yellow
$jenkins = kubectl get statefulset -n jenkins jenkins --no-headers 2>$null
if ($jenkins) {
    Write-Host "✅ Jenkins deployed" -ForegroundColor Green
    $jenkinsIngress = kubectl get ingress -n jenkins -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>$null
    if ($jenkinsIngress) {
        Write-Host "   Jenkins URL: http://$jenkinsIngress" -ForegroundColor Cyan
    }
} else {
    Write-Host "⚠️  Jenkins not deployed yet" -ForegroundColor Yellow
}

# Test 9: Check application deployment
Write-Host "`n[9/10] Checking application..." -ForegroundColor Yellow
$app = kubectl get deployment eks-cicd-app --no-headers 2>$null
if ($app) {
    Write-Host "✅ Application deployed" -ForegroundColor Green
    $appIngress = kubectl get ingress eks-cicd-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>$null
    if ($appIngress) {
        Write-Host "   Application URL: http://$appIngress" -ForegroundColor Cyan
    }
} else {
    Write-Host "⚠️  Application not deployed yet" -ForegroundColor Yellow
}

# Test 10: Check ECR repository
Write-Host "`n[10/10] Checking ECR repository..." -ForegroundColor Yellow
try {
    $ecrRepos = aws ecr describe-repositories --region $Region --repository-names eks-cicd-app 2>$null | ConvertFrom-Json
    if ($ecrRepos.repositories) {
        Write-Host "✅ ECR repository exists" -ForegroundColor Green
        Write-Host "   Repository URI: $($ecrRepos.repositories[0].repositoryUri)" -ForegroundColor Cyan
    }
} catch {
    Write-Host "⚠️  ECR repository not found" -ForegroundColor Yellow
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Validation Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. If Jenkins not deployed: Run scripts/install-jenkins.ps1" -ForegroundColor White
Write-Host "2. If LB Controller not found: Run scripts/install-lb-controller.ps1" -ForegroundColor White
Write-Host "3. Access Jenkins and create a pipeline job" -ForegroundColor White
Write-Host "4. Configure pipeline to use jenkins/Jenkinsfile" -ForegroundColor White
Write-Host "5. Run pipeline to deploy application" -ForegroundColor White
