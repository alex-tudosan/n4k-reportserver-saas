# Kyverno n4k + Reports Server Testing Repository

## 🎯 Overview

This repository provides a **systematic, phased approach** to test Kyverno n4k (enhanced Kyverno) with Reports Server in production-scale environments. It includes comprehensive monitoring, automated testing, and performance analysis.

## 📖 Documentation

### **📋 [COMPREHENSIVE_GUIDE.md](COMPREHENSIVE_GUIDE.md)** - **START HERE**

This is your **single source of truth** for everything you need to know:
- ✅ **Quick Start** - Phase 1 automated setup
- ✅ **Testing Strategy** - Phased approach (Phase 1, 2, 3)
- ✅ **Manual Setup** - Step-by-step instructions
- ✅ **Monitoring** - Metrics and dashboards
- ✅ **Troubleshooting** - Common issues and solutions
- ✅ **Cost Estimation** - Monthly costs for each phase
- ✅ **Load Testing** - Production-scale testing scripts

## 🚀 Quick Start

```bash
# 1. Install prerequisites
brew install awscli eksctl kubectl helm jq

# 2. Configure AWS
aws configure
export AWS_REGION=us-west-2

# 3. Run Phase 1 (recommended starting point)
./phase1-setup.sh
./phase1-test-cases.sh
./phase1-monitor.sh
./phase1-cleanup.sh
```

## 📊 Testing Phases

| Phase | Cluster Size | Cost/Month | Purpose | Status |
|-------|-------------|------------|---------|---------|
| **Phase 1** | 2x t3a.medium (~110 pods) | ~$113 | Requirements gathering | ✅ Ready |
| **Phase 2** | 10x m5.large (~800 pods) | ~$423 | Performance validation | 📋 Planned |
| **Phase 3** | 20+ m5.2xlarge (12k pods) | ~$2,773 | Production validation | 📋 Planned |

## 📁 Repository Structure

### **Scripts** (Automated Setup)
- `phase1-setup.sh` - Phase 1 EKS cluster setup
- `phase1-test-cases.sh` - 19 comprehensive test cases
- `phase1-monitor.sh` - Real-time monitoring dashboard
- `phase1-cleanup.sh` - Cleanup with options

### **Configuration Files**
- `eks-cluster-config-phase1.yaml` - Phase 1 cluster config
- `eks-cluster-config.yaml` - Production cluster config
- `kind-config.yaml` - Local testing config (legacy)

### **ServiceMonitors** (Monitoring)
- `reports-server-servicemonitor.yaml` - Reports Server metrics
- `kyverno-servicemonitor.yaml` - Kyverno metrics
- `reports-server-etcd-servicemonitor.yaml` - etcd metrics

### **Test Files**
- `baseline-violations-pod.yaml` - Sample violating pod
- `cpolr-demo.yaml` - ClusterPolicy demo
- `kyverno-dashboard.json` - Grafana dashboard

### **Load Testing Scripts** (Phase 3)
- `create-namespaces.sh` - Create 1,425 namespaces
- `create-pods.sh` - Create 12,000 pods
- `monitor-load-test.sh` - Monitor large-scale test
- `cleanup-load-test.sh` - Cleanup large-scale test

## 🎯 What This Demo Does

**Think of it like this**: 
- **Kyverno** = Security guard that checks if your applications follow rules
- **Reports Server** = Filing cabinet that keeps detailed records of what the security guard found
- **Monitoring** = Dashboard that shows you how well everything is working

## 🔧 Versions Used
- Kyverno chart: 3.4.7 (Kyverno v1.14.3-n4k.nirmata.4)
- Reports Server chart: 0.2.3 (app v0.2.2)
- kube-prometheus-stack: latest (via prometheus-community)

## 📚 References
- [Kyverno Monitoring](https://release-1-14-0.kyverno.io/docs/monitoring/)
- [Baseline Policies](https://github.com/nirmata/kyverno-policies/tree/main/pod-security/baseline)
- [Reports Server Documentation](https://github.com/nirmata/reports-server)

---

**💡 Recommendation**: Start with Phase 1 to validate requirements before large investment. See [COMPREHENSIVE_GUIDE.md](COMPREHENSIVE_GUIDE.md) for complete details.

