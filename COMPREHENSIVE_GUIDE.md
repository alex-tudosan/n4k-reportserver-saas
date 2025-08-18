# Kyverno n4k + Reports Server: Comprehensive Testing Guide

## 🎯 Overview

This guide provides a **systematic, phased approach** to test Kyverno n4k (enhanced Kyverno) with Reports Server in production-scale environments. It includes comprehensive monitoring, automated testing, and performance analysis.

**Think of it like this**: 
- **Kyverno** = Security guard that checks if your applications follow rules
- **Reports Server** = Filing cabinet that keeps detailed records of what the security guard found
- **Monitoring** = Dashboard that shows you how well everything is working

## 📋 Testing Strategy

### **Phased Approach (Recommended)**

| Phase | Cluster Size | Cost/Month | Purpose | Scripts |
|-------|-------------|------------|---------|---------|
| **Phase 1** | 2x t3a.medium (~110 pods) | ~$113 | Requirements gathering, baseline | `phase1-*.sh` |
| **Phase 2** | 10x m5.large (~800 pods) | ~$423 | Performance validation | Manual setup |
| **Phase 3** | 20+ m5.2xlarge (12k pods) | ~$2,773 | Production validation | Manual setup |

**💡 Recommendation**: Start with Phase 1 to validate requirements before large investment.

## 🚀 Quick Start (Phase 1)

### Prerequisites
```bash
# Install required tools
brew install awscli eksctl kubectl helm jq

# Configure AWS
aws configure
export AWS_REGION=us-west-2
```

### One-Command Setup
```bash
# 1. Setup Phase 1 environment (2x t3a.medium nodes)
./phase1-setup.sh

# 2. Run comprehensive test cases
./phase1-test-cases.sh

# 3. Monitor performance (optional)
./phase1-monitor.sh

# 4. Cleanup when done
./phase1-cleanup.sh
```

### Access & Verification
```bash
# Get Grafana password
kubectl -n monitoring get secret monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d ; echo

# Port forward to Grafana
kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80

# Access URLs
echo "Grafana: http://localhost:3000 (admin/[password])"
echo "Prometheus: kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090"

# Verify setup
kubectl get pods -A
kubectl get policies -A
kubectl get polr -A
```

## 📊 Phase 1 Test Results

### Test Categories (19 Total Tests)
1. **Basic Functionality** - Component installation and startup
2. **Policy Enforcement** - Policy application and violation detection
3. **Monitoring** - Prometheus and Grafana functionality
4. **Performance** - Pod creation rate and resource usage
5. **etcd Storage** - Storage functionality and metrics
6. **API Functionality** - API responsiveness
7. **Failure Recovery** - Pod restart recovery

### Success Criteria
- ✅ All 19 test cases pass
- ✅ All components running healthy
- ✅ Policies enforcing correctly
- ✅ Reports generating properly
- ✅ Monitoring providing accurate metrics
- ✅ Resource usage within expected limits

## 🔧 Manual Setup (Alternative to Scripts)

### Phase 1: Small-Scale EKS Setup

#### 1. Create EKS Cluster
```bash
# Create Phase 1 cluster
eksctl create cluster -f eks-cluster-config-phase1.yaml

# Wait for cluster to be ready
eksctl utils wait --cluster kyverno-test-phase1 --region us-west-2

# Update kubeconfig
aws eks update-kubeconfig --name kyverno-test-phase1 --region us-west-2
```

#### 2. Install Monitoring Stack
```bash
# Add Helm repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus Operator
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

# Apply ServiceMonitors
kubectl apply -f reports-server-servicemonitor.yaml
kubectl apply -f kyverno-servicemonitor.yaml
kubectl apply -f reports-server-etcd-servicemonitor.yaml
```

#### 3. Install Reports Server
```bash
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
kubectl -n kyverno wait --for=condition=ready pod -l app.kubernetes.io/name=reports-server --timeout=300s
```

#### 4. Install Kyverno n4k
```bash
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
kubectl -n kyverno wait --for=condition=ready pod -l app.kubernetes.io/part-of=kyverno --timeout=300s
```

#### 5. Install Baseline Policies
```bash
# Clone and apply baseline policies
git clone --depth 1 https://github.com/nirmata/kyverno-policies.git
kubectl kustomize kyverno-policies/pod-security/baseline | kubectl apply -f -

# Verify policies are active
kubectl get policies -A
```

## 📈 Phase 2: Medium-Scale Testing

After successfully completing Phase 1, proceed to Phase 2 for performance validation.

### Cluster Specifications
```yaml
# eks-cluster-config-phase2.yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: kyverno-test-phase2
  region: us-west-2
  version: "1.29"

controlPlane:
  instanceType: m5.large  # 2 vCPU, 8 GB RAM
  desiredCapacity: 2
  maxPodsPerNode: 80
  
managedNodeGroups:
  - name: workload-nodes
    instanceType: m5.large  # 2 vCPU, 8 GB RAM
    desiredCapacity: 8
    maxPodsPerNode: 80
    volumeSize: 50
    labels:
      role: workload
    tags:
      k8s.io/cluster-autoscaler/node-template/label/role: workload

  - name: monitoring-nodes
    instanceType: m5.large  # 2 vCPU, 8 GB RAM
    desiredCapacity: 2
    maxPodsPerNode: 50
    volumeSize: 30
    labels:
      role: monitoring
    taints:
      - key: dedicated
        value: monitoring
        effect: NoSchedule

addons:
  - name: vpc-cni
    version: latest
  - name: coredns
    version: latest
  - name: kube-proxy
    version: latest
  - name: aws-ebs-csi-driver
    version: latest

iam:
  withOIDC: true
  serviceAccounts:
    - metadata:
        name: kyverno-sa
        namespace: kyverno
      wellKnownPolicies:
        awsLoadBalancerController: true
```

### Resource Calculations
**For ~800 pods across test workloads:**

| Component | Calculation | Requirement |
|-----------|-------------|-------------|
| **Nodes** | 10x m5.large | 20 vCPU, 80 GB RAM total |
| **Pods** | ~800 pods | Distributed across nodes |
| **CPU** | 800 pods × 0.1 CPU | ~80 CPU cores |
| **Memory** | 800 pods × 128MB | ~100 GB RAM |
| **Storage** | 800 pods × 1GB | ~800 GB storage |

### Installation Steps
```bash
# Create Phase 2 cluster
eksctl create cluster -f eks-cluster-config-phase2.yaml

# Follow similar installation steps as Phase 1, but with production settings
# Use the scripts from the original EKS_MIGRATION_GUIDE.md for full-scale setup
```

## 🏭 Phase 3: Production-Scale Testing

After Phase 2 validation, proceed to the full production-scale testing.

### Cluster Specifications
```yaml
# eks-cluster-config.yaml (original full-scale configuration)
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: kyverno-scale-test
  region: us-west-2
  version: "1.29"

controlPlane:
  instanceType: m5.xlarge  # 4 vCPU, 16 GB RAM
  desiredCapacity: 3
  maxPodsPerNode: 110
  
managedNodeGroups:
  - name: workload-nodes
    instanceType: m5.2xlarge  # 8 vCPU, 32 GB RAM
    desiredCapacity: 20
    maxPodsPerNode: 110
    volumeSize: 100
    labels:
      role: workload
    tags:
      k8s.io/cluster-autoscaler/node-template/label/role: workload

  - name: monitoring-nodes
    instanceType: m5.large  # 2 vCPU, 8 GB RAM
    desiredCapacity: 3
    maxPodsPerNode: 50
    volumeSize: 50
    labels:
      role: monitoring
    taints:
      - key: dedicated
        value: monitoring
        effect: NoSchedule

addons:
  - name: vpc-cni
    version: latest
  - name: coredns
    version: latest
  - name: kube-proxy
    version: latest
  - name: aws-ebs-csi-driver
    version: latest

iam:
  withOIDC: true
  serviceAccounts:
    - metadata:
        name: kyverno-sa
        namespace: kyverno
      wellKnownPolicies:
        awsLoadBalancerController: true
```

### Resource Calculations
**For 12,000 pods across 1,425 namespaces:**

| Component | Calculation | Requirement |
|-----------|-------------|-------------|
| **Namespaces** | 1,425 namespaces | ~8.4 pods per namespace |
| **Pods** | 12,000 pods | Distributed across namespaces |
| **Nodes** | 12,000 pods ÷ 110 pods/node | ~109 nodes minimum |
| **CPU** | 12,000 pods × 0.1 CPU | ~1,200 CPU cores |
| **Memory** | 12,000 pods × 128MB | ~1.5 TB RAM |
| **Storage** | 12,000 pods × 1GB | ~12 TB storage |

### Load Testing Scripts

#### Create Namespaces
```bash
# create-namespaces.sh
#!/bin/bash

echo "Creating 1,425 namespaces..."

for i in $(seq 1 1425); do
  kubectl create namespace scale-test-$i
  if [ $((i % 100)) -eq 0 ]; then
    echo "Created $i namespaces"
  fi
done

echo "All namespaces created!"
```

#### Create Pods
```bash
# create-pods.sh
#!/bin/bash

echo "Creating 12,000 pods across 1,425 namespaces..."

# Calculate pods per namespace (approximately 8.4 pods per namespace)
pods_per_namespace=8
extra_pods=12000

for i in $(seq 1 1425); do
  namespace="scale-test-$i"
  
  # Create base pods for this namespace
  for j in $(seq 1 $pods_per_namespace); do
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-pod-$j
  namespace: $namespace
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
      limits:
        memory: "128Mi"
        cpu: "100m"
  restartPolicy: Never
EOF
  done
  
  # Create some violating pods for policy testing
  if [ $((i % 10)) -eq 0 ]; then
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: violating-pod
  namespace: $namespace
spec:
  hostPID: true
  containers:
  - name: nginx
    image: nginx:alpine
    securityContext:
      privileged: true
EOF
  fi
  
  if [ $((i % 100)) -eq 0 ]; then
    echo "Created pods in $i namespaces"
  fi
done

echo "All pods created!"
```

#### Monitor Load Test
```bash
# monitor-load-test.sh
#!/bin/bash

echo "=== Kyverno n4k + Reports Server Load Test Monitoring ==="
echo "Monitoring 12,000 pods across 1,425 namespaces..."
echo "Press Ctrl+C to stop monitoring"
echo ""

while true; do
  clear
  echo "=== $(date) ==="
  echo ""
  
  # Cluster status
  echo "📊 CLUSTER STATUS:"
  kubectl get nodes --no-headers | wc -l | tr -d ' ' | xargs echo "  Nodes:"
  kubectl get pods -A --no-headers | wc -l | tr -d ' ' | xargs echo "  Total Pods:"
  kubectl get namespaces --no-headers | wc -l | tr -d ' ' | xargs echo "  Namespaces:"
  echo ""
  
  # Kyverno status
  echo "🛡️ KYVERNO STATUS:"
  kubectl -n kyverno get pods -o wide
  echo ""
  
  # Reports Server status
  echo "📋 REPORTS SERVER STATUS:"
  kubectl -n kyverno get pods -l app.kubernetes.io/name=reports-server -o wide
  echo ""
  
  # Resource usage
  echo "💾 RESOURCE USAGE:"
  kubectl top nodes --no-headers | head -5
  echo ""
  
  # Policy reports
  echo "📊 POLICY REPORTS:"
  kubectl get polr -A --no-headers | wc -l | tr -d ' ' | xargs echo "  Total PolicyReports:"
  kubectl get cpolr --no-headers | wc -l | tr -d ' ' | xargs echo "  Total ClusterPolicyReports:"
  echo ""
  
  # Performance metrics (if Prometheus is available)
  if kubectl -n monitoring get pods -l app=prometheus --no-headers | grep -q Running; then
    echo "📈 PERFORMANCE METRICS:"
    echo "  Kyverno admission review latency: $(kubectl -n monitoring exec deployment/monitoring-kube-prometheus-prometheus -- curl -s 'http://localhost:9090/api/v1/query?query=kyverno_admission_review_duration_seconds' | jq -r '.data.result[0].value[1] // "N/A"')"
    echo "  Reports Server API calls: $(kubectl -n monitoring exec deployment/monitoring-kube-prometheus-prometheus -- curl -s 'http://localhost:9090/api/v1/query?query=reports_server_http_requests_total' | jq -r '.data.result[0].value[1] // "N/A"')"
    echo ""
  fi
  
  # Recent events
  echo "🔔 RECENT EVENTS:"
  kubectl get events --sort-by='.lastTimestamp' --no-headers | tail -3
  echo ""
  
  sleep 10
done
```

#### Cleanup Load Test
```bash
# cleanup-load-test.sh
#!/bin/bash

echo "🧹 Cleaning up 12,000 pods load test..."

# Delete all test namespaces
echo "Deleting 1,425 test namespaces..."
for i in $(seq 1 1425); do
  kubectl delete namespace scale-test-$i --ignore-not-found=true
  if [ $((i % 100)) -eq 0 ]; then
    echo "Deleted $i namespaces"
  fi
done

echo "All test namespaces deleted!"

# Ask if user wants to delete the entire cluster
read -p "Do you want to delete the entire EKS cluster? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "Deleting EKS cluster..."
  eksctl delete cluster --name kyverno-scale-test --region us-west-2
  echo "EKS cluster deleted!"
else
  echo "EKS cluster preserved. You can delete it manually with:"
  echo "eksctl delete cluster --name kyverno-scale-test --region us-west-2"
fi
```

## 🔍 Monitoring & Metrics

### Grafana Dashboard
1. Access Grafana: `kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80`
2. Import dashboard: Upload `kyverno-dashboard.json`
3. Select Prometheus data source

### Key Metrics to Monitor

#### Kyverno Metrics
- **Admission Review Latency**: `kyverno_admission_review_duration_seconds`
- **Policy Execution Rate**: `kyverno_policy_execution_total`
- **Policy Changes**: `kyverno_policy_changes_total`

#### Reports Server Metrics
- **API Requests**: `reports_server_http_requests_total`
- **Report Generation**: `reports_server_reports_generated_total`
- **Storage Usage**: `reports_server_storage_bytes`

#### etcd Metrics
- **Database Size**: `etcd_mvcc_db_total_size_in_bytes`
- **Quota Usage**: `etcd_server_quota_backend_bytes`
- **Cluster Health**: `etcd_server_health_success`

### Prometheus Queries

#### Reports Server etcd Storage
```promql
# Quota per member (GiB)
etcd_server_quota_backend_bytes{namespace="kyverno",job="etcd"} / 1024^3

# DB size per member (MiB)
etcd_mvcc_db_total_size_in_bytes{namespace="kyverno",job="etcd"} / 1024 / 1024

# Percent used per member
100 * (etcd_mvcc_db_total_size_in_bytes{namespace="kyverno",job="etcd"} / on(pod) etcd_server_quota_backend_bytes{namespace="kyverno",job="etcd"})

# GiB remaining per member
(etcd_server_quota_backend_bytes{namespace="kyverno",job="etcd"} - etcd_mvcc_db_total_size_in_bytes{namespace="kyverno",job="etcd"}) / 1024^3
```

## 🛠️ Troubleshooting

### Common Issues

| Problem | Solution |
|---------|----------|
| AWS credentials not configured | `aws configure` |
| eksctl not installed | `brew install eksctl` |
| Cluster creation fails | Check AWS region and permissions |
| Helm fails | `helm repo update` |
| Pods pending | Check node resources |
| Can't access Grafana | Use port-forward instead of NodePort |
| No reports | Wait 1-2 minutes for policies to activate |

### Verification Commands
```bash
# Check all components are running
kubectl get pods -A

# Check policies are active
kubectl get policies -A

# Check reports are being generated
kubectl get polr -A

# Check monitoring is working
kubectl -n monitoring get servicemonitors

# Check cluster resources
kubectl get nodes
kubectl top nodes
```

## 💰 Cost Estimation

### Phase 1: Small-Scale Testing
**Estimated monthly cost: ~$113**
- EKS Control Plane: ~$73/month
- 2x t3a.medium nodes: ~$30/month
- EBS Storage: ~$10/month

### Phase 2: Medium-Scale Testing
**Estimated monthly cost: ~$423**
- EKS Control Plane: ~$73/month
- 10x m5.large nodes: ~$300/month
- EBS Storage: ~$50/month

### Phase 3: Production-Scale Testing
**Estimated monthly cost: ~$2,773**
- EKS Control Plane: ~$73/month
- 20x m5.2xlarge nodes: ~$2,400/month
- 3x m5.large monitoring nodes: ~$180/month
- EBS Storage: ~$120/month

### Cost Optimization Tips
- Use Spot instances (50-70% savings)
- Implement auto-scaling
- Use reserved instances for production
- Monitor and right-size resources
- **Start with Phase 1** to validate requirements before large investment

## 🧹 Cleanup

### Phase 1 Cleanup
```bash
# Complete cleanup with options
./phase1-cleanup.sh
```

### Phase 2 & 3 Cleanup
```bash
# Remove test workloads
for i in $(seq 1 1425); do
  kubectl delete namespace scale-test-$i
done

# Delete EKS clusters
eksctl delete cluster --name kyverno-test-phase2 --region us-west-2
eksctl delete cluster --name kyverno-scale-test --region us-west-2
```

## 📚 Additional Resources

### Repository Contents
- **Configuration Files**:
  - `eks-cluster-config-phase1.yaml` - Phase 1 cluster config
  - `eks-cluster-config.yaml` - Production cluster config
  - `kind-config.yaml` - Local testing config (legacy)

- **ServiceMonitors**:
  - `reports-server-servicemonitor.yaml` - Reports Server metrics
  - `kyverno-servicemonitor.yaml` - Kyverno metrics
  - `reports-server-etcd-servicemonitor.yaml` - etcd metrics

- **Test Files**:
  - `baseline-violations-pod.yaml` - Sample violating pod
  - `cpolr-demo.yaml` - ClusterPolicy demo
  - `kyverno-dashboard.json` - Grafana dashboard

- **Scripts**:
  - `phase1-setup.sh` - Phase 1 automated setup
  - `phase1-test-cases.sh` - Phase 1 test execution
  - `phase1-monitor.sh` - Phase 1 monitoring
  - `phase1-cleanup.sh` - Phase 1 cleanup

### References
- [Kyverno Monitoring](https://release-1-14-0.kyverno.io/docs/monitoring/)
- [Baseline Policies](https://github.com/nirmata/kyverno-policies/tree/main/pod-security/baseline)
- [Reports Server Documentation](https://github.com/nirmata/reports-server)

## 🎯 Summary

This comprehensive guide provides a **systematic, phased approach** to testing Kyverno n4k + Reports Server:

### **Recommended Approach**
1. **Start with Phase 1** (~$113/month) - Validate requirements and establish baseline
2. **Proceed to Phase 2** (~$423/month) - Performance validation and scaling tests
3. **Complete with Phase 3** (~$2,773/month) - Full production-scale validation

### **Key Benefits**
- **Risk Mitigation**: Validate everything before large investment
- **Cost Control**: Start small and scale based on actual requirements
- **Learning Curve**: Build expertise incrementally
- **Requirements Gathering**: Establish baseline metrics and performance targets
- **Iterative Improvement**: Refine specifications based on real-world testing

### **Quick Start**
```bash
# Phase 1: Start here
./phase1-setup.sh
./phase1-test-cases.sh
./phase1-monitor.sh
./phase1-cleanup.sh
```

This systematic approach ensures successful testing of Kyverno n4k + Reports Server with comprehensive monitoring and performance analysis.
