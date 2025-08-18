# Quick Start Reference Card

## 🎯 **Recommended Approach: Start with Phase 1**

This repository provides a **systematic, phased testing approach** for Kyverno n4k + Reports Server:

- **Phase 1**: Small-scale EKS testing (~$113/month) - **START HERE**
- **Phase 2**: Medium-scale testing (~$423/month)
- **Phase 3**: Production-scale testing (~$2,773/month)

## 🚀 **Phase 1: Quick Start (Recommended)**

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

## 🔑 **Phase 1 Access Credentials**

```bash
# Get Grafana password
kubectl -n monitoring get secret monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d ; echo

# Access URLs (after port-forward)
kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80
echo "Grafana: http://localhost:3000 (admin/[password])"
echo "Prometheus: kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090"
```

## ✅ **Phase 1 Verification Commands**

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

## 🧹 **Phase 1 Cleanup**

```bash
# Complete cleanup with options
./phase1-cleanup.sh

# Or manual cleanup
kubectl delete namespace kyverno --ignore-not-found=true
kubectl delete namespace monitoring --ignore-not-found=true
eksctl delete cluster --name kyverno-test-phase1 --region us-west-2
```

## 📊 **Phase 1 What You'll See**

- **19 Test Cases**: Comprehensive validation across 7 categories
- **Grafana Dashboard**: Import `kyverno-dashboard.json` for metrics
- **Policy Reports**: View violations at `kubectl get polr -A`
- **Performance Metrics**: Monitor latency, throughput, and resource usage
- **Storage Monitoring**: Track etcd usage for Reports Server
- **Resource Usage**: Monitor 2x t3a.medium nodes (~110 pods capacity)

## 🆘 **Phase 1 Quick Troubleshooting**

| Problem | Solution |
|---------|----------|
| AWS credentials not configured | `aws configure` |
| eksctl not installed | `brew install eksctl` |
| Cluster creation fails | Check AWS region and permissions |
| Helm fails | `helm repo update` |
| Pods pending | Check node resources |
| Can't access Grafana | Use port-forward instead of NodePort |
| No reports | Wait 1-2 minutes for policies to activate |

## 🚀 **Next Steps After Phase 1**

### Phase 2: Medium-Scale Testing
```bash
# After Phase 1 success, proceed to Phase 2
# Follow EKS_MIGRATION_GUIDE.md for Phase 2 specifications
# Expected cost: ~$423/month
```

### Phase 3: Production-Scale Testing
```bash
# After Phase 2 validation, proceed to Phase 3
# Follow EKS_MIGRATION_GUIDE.md for Phase 3 specifications
# Expected cost: ~$2,773/month
```

## 📋 **Documentation**

- **EKS_MIGRATION_GUIDE.md**: Complete phased testing approach
- **TESTING_APPROACH.md**: Systematic testing strategy
- **IMPLEMENTATION_GUIDE.md**: Detailed KIND cluster setup
