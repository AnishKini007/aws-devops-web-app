# Jenkins Configuration Restoration Guide

## Overview
This document contains instructions to restore your Jenkins configuration and pipeline after redeploying infrastructure.

## Saved Components
All configuration is version-controlled in this repository:
- ✅ **Jenkinsfile**: `jenkins/Jenkinsfile`
- ✅ **Jenkins Helm Values**: `helm/jenkins/values.yaml`
- ✅ **Jenkins RBAC**: `k8s/jenkins-rbac.yaml`
- ✅ **Infrastructure**: All Terraform code in `terraform/`

## Restoration Steps

### 1. Deploy Infrastructure
```bash
cd terraform
terraform init
terraform apply -auto-approve
```

### 2. Configure kubectl
```bash
aws eks update-kubeconfig --region ap-south-1 --name eks-cicd-cluster
```

### 3. Install AWS Load Balancer Controller
```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=eks-cicd-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

### 4. Apply Jenkins RBAC
```bash
kubectl apply -f k8s/jenkins-rbac.yaml
```

### 5. Install Jenkins
```bash
cd helm/jenkins
kubectl apply -f setup.yaml
cd ../..
helm repo add jenkins https://charts.jenkins.io
helm repo update
helm install jenkins jenkins/jenkins \
  -f helm/jenkins/values.yaml \
  --namespace jenkins \
  --create-namespace \
  --wait \
  --timeout 10m
```

### 6. Get Jenkins Admin Password
```bash
kubectl get secret jenkins -n jenkins -o jsonpath='{.data.jenkins-admin-password}' | base64 -d
```

### 7. Access Jenkins
```bash
kubectl get svc -n jenkins
# Look for the LoadBalancer External-IP (ALB)
```

### 8. Recreate Pipeline Job

1. Open Jenkins UI: `http://<ALB-URL>`
2. Login with admin credentials
3. Create New Item → Pipeline
4. Name: `eks-cicd-app-pipeline`
5. Configure:
   - **Pipeline Definition**: Pipeline script from SCM
   - **SCM**: Git
   - **Repository URL**: `https://github.com/AnishKini007/aws-devops-web-app.git`
   - **Branch**: `*/main`
   - **Script Path**: `jenkins/Jenkinsfile`
6. Save

### 9. Configure GitHub Webhook (Optional)
1. Go to GitHub repo → Settings → Webhooks
2. Add webhook:
   - Payload URL: `http://<JENKINS-ALB>/github-webhook/`
   - Content type: `application/json`
   - Events: Just the push event

## Key Configuration Values

### AWS Region
- `ap-south-1`

### EKS Cluster
- Name: `eks-cicd-cluster`
- Version: `1.31`

### ECR Repository
- `975050192962.dkr.ecr.ap-south-1.amazonaws.com/eks-cicd-app`

### IAM Roles (Created by Terraform)
- Jenkins Service Account: `jenkins-sa-role`
- App Service Account: `app-sa-role`
- LB Controller: `lb-controller-role`

### Kubernetes Resources
- Jenkins Namespace: `jenkins`
- App Namespace: `default`
- Service Accounts: Created by Helm/Terraform with IRSA

## Verification

After restoration, verify:
```bash
# Check EKS nodes
kubectl get nodes

# Check Jenkins
kubectl get all -n jenkins

# Check LB Controller
kubectl get pods -n kube-system | grep aws-load-balancer

# Run test pipeline
# Trigger build in Jenkins UI
```

## Important Notes

1. **Admin Password**: Will be regenerated - retrieve with step 6
2. **Plugin Updates**: May need to update Jenkins plugins to latest versions
3. **GitHub Credentials**: No credentials needed (public repo)
4. **AWS Costs**: Remember to destroy when not in use
5. **State File**: Keep `terraform.tfstate` backed up (in `.gitignore` - store separately)

## Estimated Setup Time
- Infrastructure: 15-20 minutes
- Jenkins Installation: 5-10 minutes
- Pipeline Configuration: 2-3 minutes
- **Total**: ~25-35 minutes

## Cost Reminder
- Infrastructure runs ~$229-259/month in ap-south-1
- Shut down when not in use: `terraform destroy -auto-approve`
