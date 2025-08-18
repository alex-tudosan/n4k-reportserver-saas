# EKS Migration Guide: From KIND to Production-Scale Testing

## Overview

This guide provides a **systematic approach** to migrate from the local KIND cluster to Amazon EKS and test Kyverno n4k + Reports Server at production scale. We use a **phased testing strategy** to validate requirements, gather performance data, and ensure success before committing to full-scale workloads.

## Testing Strategy

### Phase 1: Small-Scale Testing (Requirements Gathering)
- **Cluster**: 2x t3a.medium nodes (~110 pods capacity)
- **Cost**: ~$50-80/month
- **Purpose**: Validate basic functionality, establish monitoring, create test cases
- **Scripts**: `phase1-setup.sh`, `phase1-test-cases.sh`, `phase1-monitor.sh`, `phase1-cleanup.sh`

### Phase 2: Medium-Scale Testing (Performance Validation)
- **Cluster**: 5-10x m5.large nodes (~500-1,000 pods capacity)
- **Cost**: ~$200-400/month
- **Purpose**: Performance testing, scaling validation, resource optimization

### Phase 3: Production-Scale Testing (Final Validation)
- **Cluster**: 20+ m5.2xlarge nodes (12,000 pods across 1,425 namespaces)
- **Cost**: ~$2,773/month
- **Purpose**: Production workload validation, final performance verification

**💡 Recommendation**: Start with Phase 1 to validate requirements and establish baseline metrics before scaling up.

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

## Phase 1: Small-Scale Testing (Recommended Starting Point)

### Quick Start for Phase 1

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

### Phase 1 Cluster Specifications

**Small-Scale EKS Configuration for Requirements Gathering:**
```yaml
# eks-cluster-config.yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: kyverno-test-phase1
  region: us-west-2
  version: "1.29"

# Control plane specifications (minimal for testing)
controlPlane:
  instanceType: t3a.medium  # 2 vCPU, 4 GB RAM
  desiredCapacity: 1
  maxPodsPerNode: 50
  
# Node groups for workload pods (small scale for Phase 1)
managedNodeGroups:
  - name: workload-nodes
    instanceType: t3a.medium  # 2 vCPU, 4 GB RAM
    desiredCapacity: 2
    maxPodsPerNode: 50
    volumeSize: 20
    labels:
      role: workload
    tags:
      k8s.io/cluster-autoscaler/node-template/label/role: workload

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

### Phase 1 Resource Calculations

**For ~110 pods across test workloads:**

| Component | Calculation | Requirement |
|-----------|-------------|-------------|
| **Nodes** | 2x t3a.medium | 4 vCPU, 8 GB RAM total |
| **Pods** | ~110 pods | Distributed across nodes |
| **CPU** | 110 pods × 0.1 CPU | ~11 CPU cores |
| **Memory** | 110 pods × 128MB | ~14 GB RAM |
| **Storage** | 110 pods × 1GB | ~110 GB storage |

### Phase 1 Success Criteria

- ✅ All components install successfully
- ✅ Policies enforce correctly
- ✅ Reports generate and store properly
- ✅ Monitoring provides accurate metrics
- ✅ Basic performance meets expectations
- ✅ Resource usage within expected limits

## Step 2: Create the Phase 1 EKS Cluster

```bash
# Create the Phase 1 cluster
eksctl create cluster -f eks-cluster-config-phase1.yaml

# Wait for cluster to be ready
eksctl utils wait --cluster kyverno-test-phase1 --region us-west-2

# Update kubeconfig
aws eks update-kubeconfig --name kyverno-test-phase1 --region us-west-2

# Verify cluster access
kubectl get nodes
kubectl get pods -A
```

## Step 3: Install Monitoring Stack (Phase 1)

### Install Prometheus Operator
```bash
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
kubectl -n monitoring wait --for=condition=ready pod -l app.kubernetes.io/name=grafana --timeout=300s
```

### Configure ServiceMonitors
```bash
# Apply ServiceMonitors for Kyverno and Reports Server
kubectl apply -f reports-server-servicemonitor.yaml
kubectl apply -f kyverno-servicemonitor.yaml
kubectl apply -f reports-server-etcd-servicemonitor.yaml
```

## Step 4: Install Kyverno n4k + Reports Server (Phase 1)

### Install Reports Server (Phase 1)
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

### Install Kyverno n4k (Phase 1)
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

## Step 5: Install Baseline Policies

```bash
# Clone and apply baseline policies
git clone --depth 1 https://github.com/nirmata/kyverno-policies.git
kubectl kustomize kyverno-policies/pod-security/baseline | kubectl apply -f -

# Verify policies are active
kubectl get policies -A
```

## Step 6: Run Phase 1 Test Cases

```bash
# Run comprehensive test cases
./phase1-test-cases.sh

# Monitor performance (optional)
./phase1-monitor.sh
```

### Phase 1 Test Categories

1. **Basic Functionality Tests** - Component installation and startup
2. **Policy Enforcement Tests** - Policy application and violation detection
3. **Monitoring Tests** - Prometheus and Grafana functionality
4. **Performance Tests** - Pod creation rate and resource usage
5. **etcd Storage Tests** - Storage functionality and metrics
6. **API Functionality Tests** - API responsiveness
7. **Failure Recovery Tests** - Pod restart recovery

## Phase 2: Medium-Scale Testing (Next Step)

After successfully completing Phase 1, proceed to Phase 2 for performance validation.

### Phase 2 Cluster Specifications

**Medium-Scale EKS Configuration:**
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

### Phase 2 Resource Calculations

**For ~800 pods across test workloads:**

| Component | Calculation | Requirement |
|-----------|-------------|-------------|
| **Nodes** | 10x m5.large | 20 vCPU, 80 GB RAM total |
| **Pods** | ~800 pods | Distributed across nodes |
| **CPU** | 800 pods × 0.1 CPU | ~80 CPU cores |
| **Memory** | 800 pods × 128MB | ~100 GB RAM |
| **Storage** | 800 pods × 1GB | ~800 GB storage |

### Phase 2 Installation

```bash
# Create Phase 2 cluster
eksctl create cluster -f eks-cluster-config-phase2.yaml

# Follow similar installation steps as Phase 1, but with production settings
# Use the scripts from the original EKS_MIGRATION_GUIDE.md for full-scale setup
```

## Phase 3: Production-Scale Testing (Final Step)

After Phase 2 validation, proceed to the full production-scale testing.

### Phase 3 Cluster Specifications

**Production-Scale EKS Configuration:**
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

### Phase 3 Resource Calculations

**For 12,000 pods across 1,425 namespaces:**

| Component | Calculation | Requirement |
|-----------|-------------|-------------|
| **Namespaces** | 1,425 namespaces | ~8.4 pods per namespace |
| **Pods** | 12,000 pods | Distributed across namespaces |
| **Nodes** | 12,000 pods ÷ 110 pods/node | ~109 nodes minimum |
| **CPU** | 12,000 pods × 0.1 CPU | ~1,200 CPU cores |
| **Memory** | 12,000 pods × 128MB | ~1.5 TB RAM |
| **Storage** | 12,000 pods × 1GB | ~12 TB storage |

## Step 7: Production-Scale Load Testing Scripts

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

### Phase 1 Cleanup
```bash
# Cleanup Phase 1 environment
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

### Phase 1: Small-Scale Testing
**Estimated monthly cost: ~$50-80**
- EKS Control Plane: ~$73/month
- 2x t3a.medium nodes: ~$30/month
- EBS Storage: ~$10/month
- **Total: ~$113/month** (but can be optimized with Spot instances)

### Phase 2: Medium-Scale Testing
**Estimated monthly cost: ~$200-400**
- EKS Control Plane: ~$73/month
- 10x m5.large nodes: ~$300/month
- EBS Storage: ~$50/month
- **Total: ~$423/month**

### Phase 3: Production-Scale Testing
**Estimated monthly cost: ~$2,773**
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
- **Start with Phase 1** to validate requirements before large investment

## Summary

This guide provides a **systematic, phased approach** to migrate from KIND cluster to production-scale EKS testing:

### 🎯 **Recommended Approach**

1. **Start with Phase 1** (~$113/month) - Validate requirements and establish baseline
2. **Proceed to Phase 2** (~$423/month) - Performance validation and scaling tests
3. **Complete with Phase 3** (~$2,773/month) - Full production-scale validation

### 📋 **Key Benefits**

- **Risk Mitigation**: Validate everything before large investment
- **Cost Control**: Start small and scale based on actual requirements
- **Learning Curve**: Build expertise incrementally
- **Requirements Gathering**: Establish baseline metrics and performance targets
- **Iterative Improvement**: Refine specifications based on real-world testing

### 🚀 **Quick Start**

```bash
# Phase 1: Start here
./phase1-setup.sh
./phase1-test-cases.sh
./phase1-monitor.sh
./phase1-cleanup.sh

# Phase 2: After Phase 1 success
# Follow Phase 2 specifications in this guide

# Phase 3: After Phase 2 validation
# Follow Phase 3 specifications in this guide
```

### 📊 **Success Metrics**

- **Phase 1**: All 19 test cases pass, baseline metrics established
- **Phase 2**: Performance targets met, scaling validated
- **Phase 3**: Production workload validated, 12k pods successfully tested

This systematic approach ensures successful migration from KIND to production-scale EKS testing with comprehensive monitoring and performance analysis.
