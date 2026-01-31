# ========================================
# Jenkins Deployment Instructions
# ========================================

## Prerequisites

1. **EKS Cluster**: Ensure EKS cluster is running
2. **kubectl**: Configured to access the cluster
3. **Helm**: Installed (version 3.x)
4. **AWS Load Balancer Controller**: Deployed on the cluster

## Step 1: Update Service Account with IAM Role ARN

Get the Jenkins IAM role ARN from Terraform:
```bash
cd terraform
terraform output jenkins_role_arn
```

Update the role ARN in both:
- `helm/jenkins/values.yaml` (line ~30)
- `helm/jenkins/setup.yaml` (line ~25)

Replace `arn:aws:iam::ACCOUNT_ID:role/eks-cicd-cluster-jenkins-sa-role` with actual ARN.

## Step 2: Create Kubernetes Resources

```bash
# Create namespace and prerequisites
kubectl apply -f helm/jenkins/setup.yaml

# Verify namespace created
kubectl get namespace jenkins

# Generate and set Jenkins admin password
JENKINS_PASSWORD=$(openssl rand -base64 32)
echo "Jenkins Admin Password: $JENKINS_PASSWORD"

kubectl create secret generic jenkins-admin-secret \
  --from-literal=jenkins-admin-password="$JENKINS_PASSWORD" \
  --namespace=jenkins \
  --dry-run=client -o yaml | kubectl apply -f -
```

## Step 3: Add Jenkins Helm Repository

```bash
helm repo add jenkins https://charts.jenkins.io
helm repo update
```

## Step 4: Install Jenkins with Helm

```bash
# Install Jenkins
helm install jenkins jenkins/jenkins \
  --namespace jenkins \
  --values helm/jenkins/values.yaml \
  --set controller.adminPassword="$JENKINS_PASSWORD" \
  --timeout 10m

# Wait for Jenkins to be ready
kubectl rollout status statefulset/jenkins --namespace=jenkins -w
```

## Step 5: Get Jenkins URL

```bash
# Get Load Balancer URL
kubectl get ingress -n jenkins

# Wait for ALB to be provisioned (may take 2-3 minutes)
JENKINS_URL=$(kubectl get ingress jenkins -n jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Jenkins URL: http://$JENKINS_URL"
```

## Step 6: Access Jenkins

1. Open browser: `http://<ALB_URL>`
2. Login with:
   - Username: `admin`
   - Password: `$JENKINS_PASSWORD` (from Step 2)

## Step 7: Verify Kubernetes Plugin

1. Navigate to **Manage Jenkins** → **Nodes and Clouds**
2. Click **Configure Clouds**
3. Verify Kubernetes cloud is configured
4. Test by creating a simple pipeline job

## Troubleshooting

### Jenkins pod not starting
```bash
kubectl describe pod -l app.kubernetes.io/name=jenkins -n jenkins
kubectl logs -l app.kubernetes.io/name=jenkins -n jenkins --tail=100
```

### Ingress not getting ALB
```bash
kubectl describe ingress jenkins -n jenkins
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

### Permission issues
```bash
# Verify service account annotation
kubectl get sa jenkins -n jenkins -o yaml

# Check if IRSA is working
kubectl exec -it deployment/jenkins -n jenkins -- env | grep AWS
```

## Upgrade Jenkins

```bash
helm upgrade jenkins jenkins/jenkins \
  --namespace jenkins \
  --values helm/jenkins/values.yaml \
  --reuse-values
```

## Uninstall Jenkins

```bash
helm uninstall jenkins --namespace jenkins
kubectl delete namespace jenkins
```
