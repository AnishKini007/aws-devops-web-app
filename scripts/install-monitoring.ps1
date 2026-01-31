# ========================================
# Prometheus & Grafana Installation Script
# ========================================
# This script installs the kube-prometheus-stack for complete monitoring

param(
    [Parameter(Mandatory=$false)]
    [string]$Namespace = "monitoring"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Installing Prometheus & Grafana Stack" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Step 1: Add Prometheus Community Helm repository
Write-Host "[1/5] Adding Prometheus Helm repository..." -ForegroundColor Yellow
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
Write-Host "✅ Helm repositories added`n" -ForegroundColor Green

# Step 2: Create namespace
Write-Host "[2/5] Creating monitoring namespace..." -ForegroundColor Yellow
kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -
Write-Host "✅ Namespace created`n" -ForegroundColor Green

# Step 3: Install kube-prometheus-stack
Write-Host "[3/5] Installing kube-prometheus-stack..." -ForegroundColor Yellow
Write-Host "This may take 3-5 minutes...`n" -ForegroundColor Yellow

helm install prometheus prometheus-community/kube-prometheus-stack `
  --namespace $Namespace `
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false `
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false `
  --set prometheus.prometheusSpec.retention=7d `
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=gp3 `
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=20Gi `
  --set grafana.adminPassword="admin" `
  --set grafana.persistence.enabled=true `
  --set grafana.persistence.storageClassName=gp3 `
  --set grafana.persistence.size=10Gi `
  --set alertmanager.enabled=true `
  --wait `
  --timeout 10m

Write-Host "✅ kube-prometheus-stack installed`n" -ForegroundColor Green

# Step 4: Wait for pods to be ready
Write-Host "[4/5] Waiting for pods to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n $Namespace --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n $Namespace --timeout=300s
Write-Host "✅ All pods ready`n" -ForegroundColor Green

# Step 5: Display access information
Write-Host "[5/5] Getting access information..." -ForegroundColor Yellow

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "📊 Grafana Dashboard:" -ForegroundColor Yellow
Write-Host "   Port-forward: kubectl port-forward -n $Namespace svc/prometheus-grafana 3000:80" -ForegroundColor White
Write-Host "   URL: http://localhost:3000" -ForegroundColor White
Write-Host "   Username: admin" -ForegroundColor White
Write-Host "   Password: admin" -ForegroundColor White

Write-Host "`n📈 Prometheus UI:" -ForegroundColor Yellow
Write-Host "   Port-forward: kubectl port-forward -n $Namespace svc/prometheus-kube-prometheus-prometheus 9090:9090" -ForegroundColor White
Write-Host "   URL: http://localhost:9090" -ForegroundColor White

Write-Host "`n🔔 Alertmanager:" -ForegroundColor Yellow
Write-Host "   Port-forward: kubectl port-forward -n $Namespace svc/prometheus-kube-prometheus-alertmanager 9093:9093" -ForegroundColor White
Write-Host "   URL: http://localhost:9093" -ForegroundColor White

Write-Host "`n📋 Pre-configured Grafana Dashboards:" -ForegroundColor Yellow
Write-Host "   - Kubernetes / Compute Resources / Cluster" -ForegroundColor White
Write-Host "   - Kubernetes / Compute Resources / Namespace (Pods)" -ForegroundColor White
Write-Host "   - Kubernetes / Compute Resources / Node (Pods)" -ForegroundColor White
Write-Host "   - Kubernetes / Networking / Cluster" -ForegroundColor White
Write-Host "   - Node Exporter / Nodes" -ForegroundColor White

Write-Host "`n🔍 Verify Installation:" -ForegroundColor Yellow
Write-Host "   kubectl get pods -n $Namespace" -ForegroundColor White
Write-Host "   kubectl get servicemonitors -A" -ForegroundColor White

Write-Host "`n========================================`n" -ForegroundColor Cyan
