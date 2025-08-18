#!/bin/bash

echo "🚀 Phase 1: Small-Scale EKS Cluster Setup"
echo "=========================================="
echo "Testing Kyverno n4k + Reports Server with minimal resources"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo "📋 Checking prerequisites..."
if ! command_exists aws; then
    echo "❌ AWS CLI is not installed. Please install it first."
    exit 1
fi

if ! command_exists eksctl; then
    echo "❌ eksctl is not installed. Please install it first."
    exit 1
fi

if ! command_exists kubectl; then
    echo "❌ kubectl is not installed. Please install it first."
    exit 1
fi

if ! command_exists helm; then
    echo "❌ helm is not installed. Please install it first."
    exit 1
fi

echo "✅ All prerequisites are installed"

# Check AWS configuration
echo ""
echo "📋 Checking AWS configuration..."
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "❌ AWS credentials not configured. Please run 'aws configure' first."
    exit 1
fi

echo "✅ AWS credentials are configured"

# Set AWS region
export AWS_REGION=us-west-2
echo "🌍 Using AWS region: $AWS_REGION"

echo ""
echo "📋 Step 1: Creating EKS cluster..."
echo "--------------------------------"

# Create the cluster
eksctl create cluster -f eks-cluster-config-phase1.yaml

if [ $? -ne 0 ]; then
    echo "❌ Failed to create EKS cluster"
    exit 1
fi

echo "✅ EKS cluster created successfully"

# Wait for cluster to be ready
echo ""
echo "⏳ Waiting for cluster to be ready..."
eksctl utils wait --cluster kyverno-test-phase1 --region us-west-2

# Update kubeconfig
echo ""
echo "📋 Updating kubeconfig..."
aws eks update-kubeconfig --name kyverno-test-phase1 --region us-west-2

# Verify cluster access
echo ""
echo "📋 Verifying cluster access..."
kubectl get nodes
kubectl get pods -A

echo ""
echo "📋 Step 2: Installing monitoring stack..."
echo "----------------------------------------"

# Add Helm repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus Operator (minimal for Phase 1)
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.enabled=true \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=gp3 \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=10Gi \
  --set prometheus.prometheusSpec.retention=1d \
  --set prometheus.prometheusSpec.resources.requests.memory=512Mi \
  --set prometheus.prometheusSpec.resources.requests.cpu=250m \
  --set prometheus.prometheusSpec.resources.limits.memory=1Gi \
  --set prometheus.prometheusSpec.resources.limits.cpu=500m

# Wait for monitoring to be ready
echo "⏳ Waiting for monitoring stack to be ready..."
kubectl -n monitoring wait --for=condition=ready pod -l app.kubernetes.io/name=grafana --timeout=300s

echo "✅ Monitoring stack installed"

echo ""
echo "📋 Step 3: Installing Reports Server..."
echo "--------------------------------------"

# Add Reports Server repository
helm repo add rs https://nirmata.github.io/reports-server/
helm repo update

# Install Reports Server (minimal for Phase 1)
helm upgrade --install reports-server rs/reports-server \
  --namespace kyverno --create-namespace \
  --version 0.2.3 \
  --set etcd.replicaCount=1 \
  --set etcd.resources.requests.memory=256Mi \
  --set etcd.resources.requests.cpu=100m \
  --set etcd.resources.limits.memory=512Mi \
  --set etcd.resources.limits.cpu=200m \
  --set etcd.persistence.size=5Gi

# Wait for Reports Server
echo "⏳ Waiting for Reports Server to be ready..."
kubectl -n kyverno wait --for=condition=ready pod -l app.kubernetes.io/name=reports-server --timeout=300s

echo "✅ Reports Server installed"

echo ""
echo "📋 Step 4: Installing Kyverno n4k..."
echo "-----------------------------------"

# Add Nirmata repository
helm repo add nirmata https://nirmata.github.io/kyverno-charts/
helm repo update

# Install Kyverno n4k (minimal for Phase 1)
helm upgrade --install kyverno nirmata/kyverno \
  --namespace kyverno --create-namespace \
  --version 3.4.7 \
  --set replicaCount=1 \
  --set resources.requests.memory=256Mi \
  --set resources.requests.cpu=100m \
  --set resources.limits.memory=512Mi \
  --set resources.limits.cpu=200m \
  --set admissionController.resources.requests.memory=256Mi \
  --set admissionController.resources.requests.cpu=100m \
  --set admissionController.resources.limits.memory=512Mi \
  --set admissionController.resources.limits.cpu=200m

# Wait for Kyverno
echo "⏳ Waiting for Kyverno to be ready..."
kubectl -n kyverno wait --for=condition=ready pod -l app.kubernetes.io/part-of=kyverno --timeout=300s

echo "✅ Kyverno n4k installed"

echo ""
echo "📋 Step 5: Setting up monitoring..."
echo "----------------------------------"

# Apply ServiceMonitors
kubectl apply -f reports-server-servicemonitor.yaml
kubectl apply -f kyverno-servicemonitor.yaml
kubectl apply -f reports-server-etcd-servicemonitor.yaml

echo "✅ ServiceMonitors configured"

echo ""
echo "📋 Step 6: Installing baseline policies..."
echo "-----------------------------------------"

# Clone and apply baseline policies
git clone --depth 1 https://github.com/nirmata/kyverno-policies.git
kubectl kustomize kyverno-policies/pod-security/baseline | kubectl apply -f -

echo "✅ Baseline policies installed"

echo ""
echo "📋 Step 7: Verification..."
echo "--------------------------"

# Check all components
echo "Checking cluster status..."
kubectl get nodes
echo ""

echo "Checking all pods..."
kubectl get pods -A
echo ""

echo "Checking policies..."
kubectl get policies -A
echo ""

echo "Checking ServiceMonitors..."
kubectl -n monitoring get servicemonitors
echo ""

echo ""
echo "🎉 Phase 1 Setup Complete!"
echo "=========================="
echo ""
echo "📊 Cluster Information:"
echo "- Cluster Name: kyverno-test-phase1"
echo "- Region: us-west-2"
echo "- Nodes: 2x t3a.medium (2 vCPU, 4 GB RAM each)"
echo "- Expected Capacity: ~110 pods"
echo ""
echo "🔗 Access Information:"
echo "- Grafana: kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80"
echo "- Prometheus: kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090"
echo ""
echo "📋 Next Steps:"
echo "1. Run test cases: ./phase1-test-cases.sh"
echo "2. Monitor performance: ./phase1-monitor.sh"
echo "3. Cleanup when done: ./phase1-cleanup.sh"
echo ""
echo "💡 This is a minimal setup for requirements gathering and test case validation."
