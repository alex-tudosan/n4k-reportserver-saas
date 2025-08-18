# EKS Migration Guide: From KIND to Production-Scale Testing

## Overview

This guide helps you migrate from the local KIND cluster to an Amazon EKS cluster and test Kyverno n4k + Reports Server with **12,000 pods across 1,425 namespaces** - a production-scale workload.

## Prerequisites

### AWS Requirements
```bash
# Install AWS CLI
brew install awscli  # macOS
# or download from https://aws.amazon.com/cli/

# Install eksctl
brew install eksctl  # macOS
# or download from https://eksctl.io/

# Install kubectl (if not already installed)
brew install kubectl

# Verify installations
aws --version
eksctl version
kubectl version --client
```

### AWS Configuration
```bash
# Configure AWS credentials
aws configure

# Set your AWS region (recommended: us-west-2, us-east-1, or eu-west-1)
export AWS_REGION=us-west-2
```

## Step 1: Design the EKS Cluster Architecture

### Cluster Specifications for 12k Pods

**Recommended EKS Configuration:**
```yaml
# eks-cluster-config.yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: kyverno-scale-test
  region: us-west-2
  version: "1.29"

# Control plane specifications
controlPlane:
  instanceType: m5.xlarge  # 4 vCPU, 16 GB RAM
  desiredCapacity: 3
  maxPodsPerNode: 110
  
# Node groups for workload pods
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

# Add-ons
addons:
  - name: vpc-cni
    version: latest
  - name: coredns
    version: latest
  - name: kube-proxy
    version: latest
  - name: aws-ebs-csi-driver
    version: latest

# IAM roles for service accounts
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

## Step 2: Create the EKS Cluster

```bash
# Create the cluster
eksctl create cluster -f eks-cluster-config.yaml

# Wait for cluster to be ready
eksctl utils wait --cluster kyverno-scale-test --region us-west-2

# Update kubeconfig
aws eks update-kubeconfig --name kyverno-scale-test --region us-west-2

# Verify cluster access
kubectl get nodes
kubectl get pods -A
```

## Step 3: Install Cluster Autoscaler

**Why**: Automatically scale nodes based on pod scheduling needs

```bash
# Install cluster autoscaler
kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml

# Edit the deployment to match your cluster
kubectl -n kube-system edit deployment cluster-autoscaler

# Update the command to include your cluster name:
# --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/kyverno-scale-test
```

## Step 4: Install Monitoring Stack

### Install Prometheus Operator
```bash
# Add Helm repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Prometheus Operator
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.enabled=true \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=gp3 \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=100Gi \
  --set prometheus.prometheusSpec.retention=7d \
  --set prometheus.prometheusSpec.resources.requests.memory=2Gi \
  --set prometheus.prometheusSpec.resources.requests.cpu=500m \
  --set prometheus.prometheusSpec.resources.limits.memory=4Gi \
  --set prometheus.prometheusSpec.resources.limits.cpu=1000m

# Wait for monitoring to be ready
kubectl -n monitoring wait --for=condition=ready pod -l app.kubernetes.io/name=grafana --timeout=300s
```

### Configure ServiceMonitors
```bash
# Apply ServiceMonitors for Kyverno and Reports Server
kubectl apply -f reports-server-servicemonitor.yaml
kubectl apply -f kyverno-servicemonitor.yaml
kubectl apply -f reports-server-etcd-servicemonitor.yaml
```

## Step 5: Install Kyverno n4k + Reports Server

### Install Reports Server
```bash
# Add Reports Server repository
helm repo add rs https://nirmata.github.io/reports-server/
helm repo update

# Install Reports Server with production settings
helm upgrade --install reports-server rs/reports-server \
  --namespace kyverno --create-namespace \
  --version 0.2.3 \
  --set etcd.replicaCount=3 \
  --set etcd.resources.requests.memory=1Gi \
  --set etcd.resources.requests.cpu=500m \
  --set etcd.resources.limits.memory=2Gi \
  --set etcd.resources.limits.cpu=1000m \
  --set etcd.persistence.size=50Gi

# Wait for Reports Server
kubectl -n kyverno wait --for=condition=ready pod -l app.kubernetes.io/name=reports-server --timeout=300s
```

### Install Kyverno n4k
```bash
# Add Nirmata repository
helm repo add nirmata https://nirmata.github.io/kyverno-charts/
helm repo update

# Install Kyverno n4k with production settings
helm upgrade --install kyverno nirmata/kyverno \
  --namespace kyverno --create-namespace \
  --version 3.4.7 \
  --set replicaCount=3 \
  --set resources.requests.memory=1Gi \
  --set resources.requests.cpu=500m \
  --set resources.limits.memory=2Gi \
  --set resources.limits.cpu=1000m \
  --set admissionController.resources.requests.memory=1Gi \
  --set admissionController.resources.requests.cpu=500m \
  --set admissionController.resources.limits.memory=2Gi \
  --set admissionController.resources.limits.cpu=1000m

# Wait for Kyverno
kubectl -n kyverno wait --for=condition=ready pod -l app.kubernetes.io/part-of=kyverno --timeout=300s
```

## Step 6: Install Baseline Policies

```bash
# Clone and apply baseline policies
git clone --depth 1 https://github.com/nirmata/kyverno-policies.git
kubectl kustomize kyverno-policies/pod-security/baseline | kubectl apply -f -

# Verify policies are active
kubectl get policies -A
```

## Step 7: Create Load Testing Scripts

### Namespace Creation Script
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

### Pod Creation Script
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

### Make Scripts Executable
```bash
chmod +x create-namespaces.sh create-pods.sh
```

## Step 8: Execute Load Testing

### Phase 1: Create Namespaces
```bash
# Create all namespaces
./create-namespaces.sh

# Verify namespace creation
kubectl get namespaces | grep scale-test | wc -l
```

### Phase 2: Create Pods
```bash
# Create all pods
./create-pods.sh

# Monitor pod creation
kubectl get pods -A | grep scale-test | wc -l
```

### Phase 3: Monitor System Performance

#### Check Cluster Resources
```bash
# Monitor node resources
kubectl top nodes

# Monitor pod resources
kubectl top pods -A

# Check cluster autoscaler
kubectl -n kube-system logs -l app=cluster-autoscaler --tail=50
```

#### Monitor Kyverno Performance
```bash
# Check Kyverno pods
kubectl -n kyverno get pods

# Check Kyverno logs
kubectl -n kyverno logs -l app.kubernetes.io/part-of=kyverno --tail=100

# Check policy reports
kubectl get polr -A | wc -l
kubectl get cpolr | wc -l
```

#### Monitor Reports Server
```bash
# Check Reports Server pods
kubectl -n kyverno get pods -l app.kubernetes.io/name=reports-server

# Check etcd storage
kubectl -n kyverno exec etcd-0 -c etcd -- etcdctl endpoint status --write-out=table
```

## Step 9: Performance Monitoring

### Grafana Dashboard Setup
```bash
# Get Grafana admin password
kubectl -n monitoring get secret monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d ; echo

# Port forward to Grafana
kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80
```

**Access Grafana at**: http://localhost:3000
- Username: `admin`
- Password: (from command above)

### Import Kyverno Dashboard
1. Go to Dashboards → Import
2. Upload `kyverno-dashboard.json`
3. Select Prometheus data source
4. Click Import

### Key Metrics to Monitor

#### Kyverno Metrics
```promql
# Admission request rate
rate(kyverno_admission_requests_total[5m])

# Policy execution latency
histogram_quantile(0.95, rate(kyverno_policy_execution_duration_seconds_bucket[5m]))

# Policy results
sum(rate(kyverno_policy_results_total[5m])) by (rule_result)
```

#### Reports Server Metrics
```promql
# API request rate
rate(apiserver_request_duration_seconds_count{group=~"reports.kyverno.io|wgpolicyk8s.io"}[5m])

# API latency
histogram_quantile(0.95, rate(apiserver_request_duration_seconds_bucket{group=~"reports.kyverno.io|wgpolicyk8s.io"}[5m]))
```

#### etcd Metrics
```promql
# etcd storage usage
etcd_mvcc_db_total_size_in_bytes{namespace="kyverno"}

# etcd performance
rate(etcd_grpc_requests_total{namespace="kyverno"}[5m])
```

## Step 10: Performance Analysis

### Success Criteria
- ✅ All 12,000 pods successfully created
- ✅ Kyverno admission latency < 100ms (95th percentile)
- ✅ Reports Server API latency < 1s (95th percentile)
- ✅ No pod scheduling failures
- ✅ etcd storage usage within limits
- ✅ Policy reports generated for all violations

### Performance Targets
| Metric | Target | Alert Threshold |
|--------|--------|----------------|
| Kyverno Admission Latency | < 100ms | > 500ms |
| Reports Server API Latency | < 1s | > 2s |
| etcd Storage Usage | < 80% | > 90% |
| Pod Creation Success Rate | > 99% | < 95% |
| Policy Report Generation | < 5s | > 10s |

## Step 11: Cleanup

### Remove Test Workloads
```bash
# Delete all test namespaces
for i in $(seq 1 1425); do
  kubectl delete namespace scale-test-$i
done
```

### Delete EKS Cluster
```bash
# Delete the entire cluster
eksctl delete cluster --name kyverno-scale-test --region us-west-2
```

## Troubleshooting

### Common Issues

#### Pod Scheduling Failures
```bash
# Check node capacity
kubectl describe nodes | grep -A 5 "Allocated resources"

# Check cluster autoscaler
kubectl -n kube-system logs -l app=cluster-autoscaler --tail=100
```

#### Kyverno Performance Issues
```bash
# Check Kyverno resource usage
kubectl -n kyverno top pods

# Check Kyverno logs for errors
kubectl -n kyverno logs -l app.kubernetes.io/part-of=kyverno --tail=200
```

#### etcd Storage Issues
```bash
# Check etcd storage usage
kubectl -n kyverno exec etcd-0 -c etcd -- etcdctl endpoint status --write-out=table

# Check etcd logs
kubectl -n kyverno logs -l app=etcd-reports-server --tail=100
```

### Scaling Recommendations

#### If Performance Degrades
1. **Increase Kyverno replicas**: `kubectl -n kyverno scale deployment kyverno --replicas=5`
2. **Increase node resources**: Modify node group instance types
3. **Optimize policies**: Review and optimize policy rules
4. **Increase etcd storage**: Scale up etcd persistence volumes

#### Cost Optimization
- Use Spot instances for workload nodes
- Implement proper resource requests/limits
- Monitor and right-size node groups
- Use AWS Savings Plans for compute costs

## Cost Estimation

**Estimated monthly cost for this setup:**
- EKS Control Plane: ~$73/month
- 20x m5.2xlarge nodes: ~$2,400/month
- 3x m5.large monitoring nodes: ~$180/month
- EBS Storage: ~$120/month
- **Total: ~$2,773/month**

**Cost optimization tips:**
- Use Spot instances (50-70% savings)
- Implement auto-scaling
- Use reserved instances for production
- Monitor and right-size resources

This guide provides a complete path from KIND cluster to production-scale EKS testing with comprehensive monitoring and performance analysis.
