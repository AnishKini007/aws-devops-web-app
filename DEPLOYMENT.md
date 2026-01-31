# ========================================
# Deployment Workflow Guide
# ========================================

## 🚀 Complete Deployment Walkthrough

### Phase 1: Infrastructure Setup (20-25 minutes)

#### Step 1: Initialize AWS Environment

```powershell
# Verify AWS CLI is configured
aws sts get-caller-identity

# Set your AWS region (if different from ap-south-1)
$env:AWS_DEFAULT_REGION = "ap-south-1"
```

#### Step 2: Deploy Infrastructure with Terraform

```powershell
cd terraform

# Initialize Terraform
terraform init

# Review the execution plan
terraform plan

# Apply infrastructure changes
terraform apply -auto-approve

# Save important outputs
terraform output > ..\terraform-outputs.txt
terraform output -json > ..\terraform-outputs.json

# Get specific values for later use
$ACCOUNT_ID = terraform output -raw account_id
$ECR_URL = terraform output -raw ecr_repository_url
$JENKINS_ROLE = terraform output -raw jenkins_role_arn
$LB_ROLE = terraform output -raw lb_controller_role_arn
$APP_ROLE = terraform output -raw app_role_arn

Write-Host "Account ID: $ACCOUNT_ID"
Write-Host "ECR URL: $ECR_URL"
Write-Host "Jenkins Role: $JENKINS_ROLE"

cd ..
```

#### Step 3: Configure kubectl

```powershell
# Update kubeconfig
aws eks update-kubeconfig --region ap-south-1 --name eks-cicd-cluster

# Verify cluster access
kubectl get nodes
kubectl get pods -A

# Verify EKS add-ons are running
kubectl get pods -n kube-system
```

---

### Phase 2: Install Core Components (10-15 minutes)

#### Step 4: Install AWS Load Balancer Controller

```powershell
# Run installation script
.\scripts\install-lb-controller.ps1

# Verify deployment
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=50
```

#### Step 5: Deploy Monitoring Stack

```powershell
# Install Prometheus & Grafana
.\scripts\install-monitoring.ps1

# Verify deployment
kubectl get pods -n monitoring

# Access Grafana (in a new terminal)
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Open browser: http://localhost:3000
# Login: admin / admin
```

#### Step 6: Apply Monitoring Configuration

```powershell
# Apply ServiceMonitors and PrometheusRules
kubectl apply -f monitoring/servicemonitors.yaml

# Verify
kubectl get servicemonitors -A
kubectl get prometheusrules -n monitoring
```

---

### Phase 3: Deploy Jenkins (10-15 minutes)

#### Step 7: Update Jenkins Configuration

```powershell
# Get Jenkins IAM role ARN
cd terraform
$JENKINS_ROLE = terraform output -raw jenkins_role_arn
cd ..

Write-Host "Jenkins Role ARN: $JENKINS_ROLE"

# Update helm/jenkins/values.yaml line ~30
# Replace: eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:..."
# With actual role ARN

# Update helm/jenkins/setup.yaml line ~25 with same ARN
```

#### Step 8: Deploy Jenkins

```powershell
# Create namespace and prerequisites
kubectl apply -f helm/jenkins/setup.yaml

# Generate secure admin password
$JENKINS_PASSWORD = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 20 | % {[char]$_})
Write-Host "`nJenkins Admin Password: $JENKINS_PASSWORD" -ForegroundColor Green
Write-Host "SAVE THIS PASSWORD!" -ForegroundColor Yellow

# Save password to file (optional)
$JENKINS_PASSWORD | Out-File -FilePath jenkins-password.txt

# Create secret
kubectl create secret generic jenkins-admin-secret `
  --from-literal=jenkins-admin-password="$JENKINS_PASSWORD" `
  --namespace=jenkins

# Add Jenkins Helm repo
helm repo add jenkins https://charts.jenkins.io
helm repo update

# Install Jenkins
helm install jenkins jenkins/jenkins `
  --namespace jenkins `
  --values helm/jenkins/values.yaml `
  --set controller.adminPassword="$JENKINS_PASSWORD" `
  --timeout 10m `
  --wait

# Wait for Jenkins to be ready
kubectl rollout status statefulset/jenkins -n jenkins -w
```

#### Step 9: Access Jenkins

```powershell
# Get Jenkins URL (wait for ALB to provision - 2-3 minutes)
Start-Sleep -Seconds 120

$JENKINS_URL = kubectl get ingress -n jenkins jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Jenkins URL: http://$JENKINS_URL" -ForegroundColor Green
Write-Host "Username: admin" -ForegroundColor Yellow
Write-Host "Password: $JENKINS_PASSWORD" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Cyan

# Open in browser
Start-Process "http://$JENKINS_URL"
```

---

### Phase 4: Configure Jenkins Pipeline (5-10 minutes)

#### Step 10: Create Jenkins Pipeline Job

1. **Access Jenkins UI** (use URL from previous step)
2. **Login** with admin credentials
3. **Create Pipeline Job**:
   - Click **"New Item"**
   - Enter name: `eks-cicd-app-pipeline`
   - Select **"Pipeline"**
   - Click **"OK"**

4. **Configure Pipeline**:
   - **General**: Check "Discard old builds" (keep 10)
   - **Build Triggers**: Check "Poll SCM" (H/5 * * * *)
   - **Pipeline** section:
     - Definition: **"Pipeline script from SCM"**
     - SCM: **"Git"**
     - Repository URL: Your Git repository URL
     - Branch: `*/main` or `*/master`
     - Script Path: `jenkins/Jenkinsfile`
   - Click **"Save"**

#### Step 11: Update Jenkinsfile with AWS Account ID

```powershell
# Get AWS Account ID
$ACCOUNT_ID = aws sts get-caller-identity --query Account --output text

Write-Host "AWS Account ID: $ACCOUNT_ID"

# Update jenkins/Jenkinsfile
# Replace placeholders in the environment section:
# - AWS_ACCOUNT_ID = "$ACCOUNT_ID"
# - ECR_REGISTRY = "${ACCOUNT_ID}.dkr.ecr.ap-south-1.amazonaws.com"
```

---

### Phase 5: Build and Deploy Application (5-10 minutes)

#### Step 12: Update Application Helm Values

```powershell
# Get application IAM role ARN
cd terraform
$APP_ROLE = terraform output -raw app_role_arn
$ECR_URL = terraform output -raw ecr_repository_url
cd ..

Write-Host "App Role ARN: $APP_ROLE"
Write-Host "ECR URL: $ECR_URL"

# Update helm/app/values.yaml:
# Line 18: repository: ${ECR_URL}
# Line 28: eks.amazonaws.com/role-arn: "${APP_ROLE}"
```

#### Step 13: Test Application Locally (Optional)

```powershell
cd app

# Build Docker image
docker build -t eks-cicd-app:local .

# Run locally
docker run -p 8080:8080 -e APP_ENV=development eks-cicd-app:local

# Test in another terminal
curl http://localhost:8080
curl http://localhost:8080/health

# Stop container
docker ps
docker stop <container_id>

cd ..
```

#### Step 14: Push Code to Git and Trigger Pipeline

```powershell
# Initialize Git repository (if not already done)
git init
git add .
git commit -m "Initial commit: EKS CI/CD platform"

# Add remote (your Git repository)
git remote add origin <your-git-repo-url>
git push -u origin main

# Or trigger manually in Jenkins UI:
# - Go to jenkins-cicd-app-pipeline
# - Click "Build Now"
```

#### Step 15: Monitor Pipeline Execution

```powershell
# Watch pipeline in Jenkins UI
# Or check from CLI:

# Get Jenkins pods
kubectl get pods -n jenkins

# Watch logs
kubectl logs -n jenkins -f statefulset/jenkins

# Check if app deployed
kubectl get pods -n default
kubectl get deployment eks-cicd-app
```

---

### Phase 6: Verify Deployment (5 minutes)

#### Step 16: Run Validation Script

```powershell
# Run comprehensive validation
.\scripts\validate-deployment.ps1

# Should show:
# ✅ AWS CLI installed
# ✅ kubectl installed
# ✅ Helm installed
# ✅ Terraform state found
# ✅ EKS cluster accessible
# ✅ Nodes ready
# ✅ AWS Load Balancer Controller deployed
# ✅ Jenkins deployed
# ✅ Application deployed
# ✅ ECR repository exists
```

#### Step 17: Access Application

```powershell
# Get application URL
$APP_URL = kubectl get ingress eks-cicd-app -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Application URL: http://$APP_URL" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

# Test endpoints
curl "http://$APP_URL"
curl "http://$APP_URL/health"
curl "http://$APP_URL/api/info"

# Open in browser
Start-Process "http://$APP_URL"
```

#### Step 18: Verify Monitoring

```powershell
# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Open http://localhost:3000
# Login: admin / admin

# Check dashboards:
# - Kubernetes / Compute Resources / Cluster
# - Kubernetes / Compute Resources / Namespace (select 'default' and 'jenkins')
# - Node Exporter / Nodes

# Access Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Open http://localhost:9090
# Query: up{namespace="jenkins"}
# Query: up{namespace="default"}
```

---

### Phase 7: Testing & Validation

#### Step 19: Test Rolling Updates

```powershell
# Make a change to app/src/index.js
# For example, change the welcome message

# Commit and push
git add app/src/index.js
git commit -m "Update welcome message"
git push

# Trigger Jenkins pipeline
# Watch rolling update:
kubectl rollout status deployment/eks-cicd-app -n default -w

# Verify zero downtime
while ($true) {
    curl "http://$APP_URL" 2>$null
    Start-Sleep -Seconds 1
}
```

#### Step 20: Test Auto-Scaling

```powershell
# Generate load (in another terminal)
while ($true) {
    curl "http://$APP_URL" 2>$null
    Start-Sleep -Milliseconds 100
}

# Watch HPA
kubectl get hpa -n default -w

# Watch pods scale
kubectl get pods -n default -w
```

---

## 📊 Post-Deployment Checklist

- [ ] VPC and subnets created
- [ ] EKS cluster running with nodes
- [ ] ECR repository accessible
- [ ] IAM roles created with IRSA
- [ ] AWS Load Balancer Controller deployed
- [ ] Prometheus & Grafana monitoring
- [ ] Jenkins accessible via ALB
- [ ] Jenkins pipeline configured
- [ ] Application deployed and accessible
- [ ] Auto-scaling working
- [ ] Monitoring dashboards showing metrics
- [ ] Alerts configured

---

## 🔧 Troubleshooting Common Issues

### Issue: Terraform fails with permission errors
**Solution**: Verify IAM user has sufficient permissions

```powershell
aws iam get-user
aws iam list-attached-user-policies --user-name <your-username>
```

### Issue: Nodes not joining cluster
**Solution**: Check node IAM role and security groups

```powershell
kubectl get nodes
aws eks describe-cluster --name eks-cicd-cluster --region us-east-1
```

### Issue: ALB not provisioning
**Solution**: Verify LB Controller logs

```powershell
kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=100
kubectl describe ingress -n jenkins
```

### Issue: Jenkins pods not starting
**Solution**: Check PVC and storage class

```powershell
kubectl get pvc -n jenkins
kubectl describe pvc -n jenkins
kubectl get sc
```

### Issue: Pipeline fails to push to ECR
**Solution**: Verify IRSA annotation on Jenkins service account

```powershell
kubectl get sa jenkins -n jenkins -o yaml
kubectl describe pod -n jenkins -l app.kubernetes.io/name=jenkins
```

---

## 🎯 Next Steps

1. **Configure SSL/TLS**: Add ACM certificate to ALB
2. **Set up monitoring alerts**: Configure Slack/email notifications
3. **Implement backup**: Schedule EBS snapshots
4. **Enable GitOps**: Integrate ArgoCD or Flux
5. **Add security scanning**: Trivy, Snyk, or Aqua
6. **Implement secrets management**: AWS Secrets Manager + External Secrets Operator
7. **Set up disaster recovery**: Multi-region or backup cluster
8. **Configure autoscaling**: Cluster Autoscaler or Karpenter

---

## 📚 Useful Commands Reference

```powershell
# Check all resources
kubectl get all -A

# Check events
kubectl get events -A --sort-by='.lastTimestamp'

# Check resource usage
kubectl top nodes
kubectl top pods -A

# Describe resources
kubectl describe node <node-name>
kubectl describe pod <pod-name> -n <namespace>

# Get logs
kubectl logs <pod-name> -n <namespace> --tail=100 -f

# Execute commands in pod
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh

# Port forwarding
kubectl port-forward -n <namespace> svc/<service-name> <local-port>:<remote-port>

# Delete resources
kubectl delete pod <pod-name> -n <namespace>
kubectl delete deployment <deployment-name> -n <namespace>

# Helm commands
helm list -A
helm history <release-name> -n <namespace>
helm rollback <release-name> <revision> -n <namespace>
```

---

**🎉 Congratulations! Your EKS CI/CD platform is now fully operational!**
