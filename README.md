# EKS CI/CD Platform

Production-grade CI/CD platform on AWS EKS with Jenkins, automated deployments, and comprehensive monitoring.

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Cloud                               │
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐   │
│  │                    VPC (10.0.0.0/16)                    │   │
│  │                                                          │   │
│  │  ┌──────────────┐          ┌──────────────┐           │   │
│  │  │ Public Subnet│          │ Public Subnet│           │   │
│  │  │  (AZ-1a)     │          │  (AZ-1b)     │           │   │
│  │  │  - ALB       │          │  - ALB       │           │   │
│  │  │  - NAT GW    │          │  - NAT GW    │           │   │
│  │  └──────────────┘          └──────────────┘           │   │
│  │         │                         │                     │   │
│  │  ┌──────────────┐          ┌──────────────┐           │   │
│  │  │Private Subnet│          │Private Subnet│           │   │
│  │  │  (AZ-1a)     │          │  (AZ-1b)     │           │   │
│  │  │ ┌──────────┐ │          │ ┌──────────┐ │           │   │
│  │  │ │EKS Nodes │ │          │ │EKS Nodes │ │           │   │
│  │  │ │- Jenkins │ │          │ │- Jenkins │ │           │   │
│  │  │ │- App Pods│ │          │ │- App Pods│ │           │   │
│  │  │ └──────────┘ │          │ └──────────┘ │           │   │
│  │  └──────────────┘          └──────────────┘           │   │
│  └────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌──────────┐     ┌──────────┐     ┌────────────┐            │
│  │   ECR    │     │   KMS    │     │ CloudWatch │            │
│  └──────────┘     └──────────┘     └────────────┘            │
└─────────────────────────────────────────────────────────────────┘
```

## 📋 Prerequisites

- **AWS Account** with appropriate permissions
- **AWS CLI** v2.x configured
- **Terraform** v1.0+
- **kubectl** v1.28+
- **Helm** v3.x
- **Docker** (for local testing)
- **Git**

## 🚀 Quick Start

### 1. Deploy Infrastructure with Terraform

```powershell
# Navigate to terraform directory
cd terraform

# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Deploy infrastructure (VPC, EKS, ECR, IAM)
terraform apply

# Save outputs
terraform output > ../outputs.txt
```

**Expected deployment time**: 15-20 minutes

### 2. Configure kubectl

```powershell
# Update kubeconfig to access EKS cluster
aws eks update-kubeconfig --region ap-south-1 --name eks-cicd-cluster

# Verify cluster access
kubectl get nodes
kubectl get pods -A
```

### 3. Install AWS Load Balancer Controller

```powershell
# Run installation script
.\scripts\install-lb-controller.ps1

# Verify installation
kubectl get deployment -n kube-system aws-load-balancer-controller
```

### 4. Deploy Jenkins

```powershell
# Update IAM role ARN in Jenkins values
# Edit helm/jenkins/values.yaml and helm/jenkins/setup.yaml
# Replace ACCOUNT_ID with your AWS account ID

# Create Jenkins namespace and resources
kubectl apply -f helm/jenkins/setup.yaml

# Generate admin password
$JENKINS_PASSWORD = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 16 | % {[char]$_})
Write-Host "Jenkins Password: $JENKINS_PASSWORD"

# Create secret
kubectl create secret generic jenkins-admin-secret `
  --from-literal=jenkins-admin-password="$JENKINS_PASSWORD" `
  --namespace=jenkins

# Add Jenkins Helm repository
helm repo add jenkins https://charts.jenkins.io
helm repo update

# Install Jenkins
helm install jenkins jenkins/jenkins `
  --namespace jenkins `
  --values helm/jenkins/values.yaml `
  --set controller.adminPassword="$JENKINS_PASSWORD" `
  --timeout 10m

# Get Jenkins URL
kubectl get ingress -n jenkins
```

### 5. Configure Jenkins Pipeline

1. Access Jenkins UI (use ALB URL from previous step)
2. Login with username `admin` and the password generated above
3. Create a new Pipeline job:
   - **New Item** → **Pipeline** → Name: `eks-cicd-app-pipeline`
   - **Pipeline** section:
     - Definition: `Pipeline script from SCM`
     - SCM: `Git`
     - Repository URL: Your Git repository
     - Script Path: `jenkins/Jenkinsfile`
4. Update `AWS_ACCOUNT_ID` in Jenkinsfile
5. Run the pipeline

### 6. Validate Deployment

```powershell
# Run validation script
.\scripts\validate-deployment.ps1

# Check application
kubectl get all -n default
kubectl get ingress
```

## 📁 Project Structure

```
aws-devops-web-app/
├── terraform/                 # Infrastructure as Code
│   ├── vpc/                   # VPC module
│   ├── eks/                   # EKS cluster module
│   ├── ecr/                   # Container registry module
│   ├── iam/                   # IAM roles and policies
│   ├── main.tf                # Root module
│   ├── variables.tf           # Input variables
│   └── outputs.tf             # Output values
├── helm/                      # Helm charts
│   ├── jenkins/               # Jenkins deployment
│   │   ├── values.yaml        # Jenkins configuration
│   │   ├── setup.yaml         # Pre-installation resources
│   │   └── README.md          # Installation guide
│   └── app/                   # Application Helm chart
│       ├── Chart.yaml         # Chart metadata
│       ├── values.yaml        # Default values
│       └── templates/         # Kubernetes manifests
├── app/                       # Sample application
│   ├── Dockerfile             # Container image
│   ├── package.json           # Dependencies
│   └── src/                   # Source code
├── jenkins/                   # Jenkins configuration
│   └── Jenkinsfile            # CI/CD pipeline
├── scripts/                   # Automation scripts
│   ├── install-lb-controller.ps1
│   └── validate-deployment.ps1
└── README.md                  # This file
```

## 🔧 Configuration

### Terraform Variables

Edit `terraform/variables.tf` to customize:

```hcl
variable "aws_region" {
  default = "ap-south-1"  # Change to your preferred region
}

variable "cluster_name" {
  default = "eks-cicd-cluster"
}

variable "project_name" {
  default = "eks-cicd"
}
```

### Jenkins Configuration

Jenkins is configured via Helm values (`helm/jenkins/values.yaml`):

- **Resources**: Adjust CPU/memory for controller and agents
- **Plugins**: Add/remove plugins in `installPlugins` section
- **IRSA**: IAM role ARN for AWS permissions
- **Storage**: PVC size for Jenkins data

### Application Configuration

Application Helm chart (`helm/app/values.yaml`):

- **Replicas**: Number of pod replicas
- **Resources**: CPU/memory requests/limits
- **Autoscaling**: HPA configuration
- **Image**: ECR repository and tag

## 🔐 Security Best Practices

✅ **Implemented**:
- VPC with private subnets for worker nodes
- IAM Roles for Service Accounts (IRSA)
- Secrets encryption with KMS
- Security groups with least-privilege rules
- IMDSv2 enforced on EC2 instances
- Container security contexts (non-root, read-only filesystem)
- Network policies (optional)
- Pod Security Standards

⚠️ **Recommended for Production**:
- Enable VPC Flow Logs
- Implement AWS WAF on ALB
- Use AWS Secrets Manager for sensitive data
- Enable EKS audit logging
- Implement OPA/Gatekeeper policies
- Set up vulnerability scanning (Trivy, Snyk)
- Configure backup solutions
- Implement disaster recovery plan

## 📊 Monitoring & Observability

### Deploy Prometheus & Grafana

```powershell
# Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack
helm install prometheus prometheus-community/kube-prometheus-stack `
  --namespace monitoring `
  --create-namespace `
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Default Grafana credentials: admin / prom-operator
```

### Available Dashboards

- **Cluster Overview**: Node CPU, memory, disk usage
- **Kubernetes Pods**: Pod status, restarts, resource usage
- **Jenkins**: Job statistics, queue length, agent status
- **Application**: Request rate, latency, error rate

## 💰 Cost Optimization

### Current Monthly Estimate

| Service | Configuration | Cost |
|---------|--------------|------|
| EKS Control Plane | 1 cluster | $73 |
| EC2 (t3.medium) | 2 nodes | $60 |
| EBS (GP3) | 60 GB | $6 |
| NAT Gateway | 2 AZs | $65 |
| ALB | 1-2 load balancers | $20-40 |
| ECR | Storage & transfer | $5-10 |
| **Total** | | **~$229-259/month** |

### Cost Reduction Tips

1. **Use Fargate for Jenkins** (pay only when jobs run)
2. **Single NAT Gateway** for dev/staging
3. **Spot Instances** for non-critical workloads
4. **Cluster Autoscaler** to scale nodes to zero during off-hours
5. **ECR Lifecycle Policies** to delete old images (already configured)
6. **Reserved Instances** for production (40-60% savings)

## 🔄 CI/CD Pipeline Flow

```
┌─────────────┐
│  Git Push   │
└──────┬──────┘
       │
       ▼
┌─────────────────────┐
│  Jenkins Pipeline   │
├─────────────────────┤
│  1. Checkout Code   │
│  2. Build & Test    │
│  3. Build Image     │
│  4. Push to ECR     │
│  5. Update k8s cfg  │
│  6. Helm Deploy     │
│  7. Verify          │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│   EKS Cluster       │
├─────────────────────┤
│  Rolling Update     │
│  Zero Downtime      │
│  Health Checks      │
└─────────────────────┘
```

## 🧪 Testing

### Test the Application Locally

```powershell
# Build Docker image
cd app
docker build -t eks-cicd-app:local .

# Run container
docker run -p 8080:8080 -e APP_ENV=development eks-cicd-app:local

# Test endpoints
curl http://localhost:8080
curl http://localhost:8080/health
curl http://localhost:8080/metrics
```

### Test Helm Chart

```powershell
# Lint Helm chart
cd helm/app
helm lint .

# Dry-run install
helm install --dry-run --debug eks-cicd-app .

# Template rendering
helm template eks-cicd-app . --values values.yaml
```

## 🐛 Troubleshooting

### EKS Cluster Not Accessible

```powershell
# Verify cluster exists
aws eks describe-cluster --region us-east-1 --name eks-cicd-cluster

# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name eks-cicd-cluster

# Check AWS credentials
aws sts get-caller-identity
```

### Pods Not Starting

```powershell
# Describe pod
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>

# Check events
kubectl get events --sort-by='.lastTimestamp'
```

### ALB Not Provisioning

```powershell
# Check LB controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verify service account
kubectl get sa -n kube-system aws-load-balancer-controller -o yaml

# Check ingress
kubectl describe ingress <ingress-name>
```

### Jenkins Pods Failing

```powershell
# Check Jenkins logs
kubectl logs -n jenkins statefulset/jenkins

# Verify PVC
kubectl get pvc -n jenkins

# Check service account
kubectl get sa -n jenkins jenkins -o yaml
```

## 📚 Additional Resources

- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [Jenkins on Kubernetes](https://www.jenkins.io/doc/book/installing/kubernetes/)
- [Helm Documentation](https://helm.sh/docs/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

## 👥 Support

For issues and questions:
- Open a GitHub issue
- Contact DevOps team
- Check AWS documentation

---

**Built with ❤️ by the DevOps Team**
