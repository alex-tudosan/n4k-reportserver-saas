# Kyverno n4k + Reports Server Implementation Guide

## What This Demo Does

This demo provides a **systematic, phased approach** to test **Kyverno n4k** (an enhanced version of Kyverno) with a **Reports Server** that stores policy reports separately from the main Kubernetes cluster. It includes comprehensive monitoring and testing tools.

**Think of it like this**: 
- Kyverno = Security guard that checks if your applications follow rules
- Reports Server = Filing cabinet that keeps detailed records of what the security guard found
- Monitoring = Dashboard that shows you how well everything is working

## Testing Strategy Overview

This repository provides **three phases** of testing, each building on the previous:

### **Phase 1: Small-Scale EKS Testing** (Recommended Starting Point)
- **Cluster**: 2x t3a.medium nodes (~110 pods capacity)
- **Cost**: ~$113/month
- **Purpose**: Validate basic functionality, establish monitoring, create test cases
- **Scripts**: `phase1-setup.sh`, `phase1-test-cases.sh`, `phase1-monitor.sh`, `phase1-cleanup.sh`

### **Phase 2: Medium-Scale Testing**
- **Cluster**: 10x m5.large nodes (~800 pods capacity)
- **Cost**: ~$423/month
- **Purpose**: Performance testing, scaling validation

### **Phase 3: Production-Scale Testing**
- **Cluster**: 20+ m5.2xlarge nodes (12,000 pods across 1,425 namespaces)
- **Cost**: ~$2,773/month
- **Purpose**: Production workload validation

**💡 Recommendation**: Start with Phase 1 to validate requirements and establish baseline metrics before scaling up.

## Prerequisites

Before starting, make sure you have these tools installed:

```bash
# Check if you have the required tools
which aws eksctl kubectl helm jq

# If any are missing, install them:
# For macOS:
brew install awscli eksctl kubectl helm jq

# For Linux:
# Follow installation guides for each tool

# Configure AWS (required for EKS)
aws configure
export AWS_REGION=us-west-2
```

## Phase 1: Quick Start (Recommended)

### Step 1: Setup Phase 1 Environment

**What we're doing**: Setting up a small-scale EKS cluster for initial testing
**Why**: We need a safe, cost-effective environment to validate requirements before scaling up

```bash
# Setup Phase 1 environment (2x t3a.medium nodes)
./phase1-setup.sh
```

**What happens**: This creates a small EKS cluster with all components installed and configured.

### Step 2: Run Test Cases

**What we're doing**: Running comprehensive test cases to validate functionality
**Why**: We need to ensure everything works correctly before proceeding

```bash
# Run comprehensive test cases
./phase1-test-cases.sh
```

**What happens**: This runs 19 test cases across 7 categories to validate all components.

### Step 3: Monitor Performance (Optional)

**What we're doing**: Monitoring system performance in real-time
**Why**: We need to understand how the system performs under load

```bash
# Monitor performance in real-time
./phase1-monitor.sh
```

**What happens**: This provides a live dashboard showing cluster status, resource usage, and performance metrics.

### Step 4: Cleanup When Done

**What we're doing**: Cleaning up the Phase 1 environment
**Why**: We need to remove resources to avoid ongoing costs

```bash
# Complete cleanup with options
./phase1-cleanup.sh
```

**What happens**: This removes all test resources and gives you options to keep or delete the EKS cluster.

## Phase 1: Access and Verification

### Access Grafana Dashboard

**What we're doing**: Accessing the monitoring dashboard
**Why**: You need to see the metrics and performance data

```bash
# Get Grafana admin password
kubectl -n monitoring get secret monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d ; echo

# Port forward to Grafana
kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80
```

**Access Grafana at**: http://localhost:3000
- Username: `admin`
- Password: (from command above)

### Verify Phase 1 Setup

**What we're doing**: Verifying that all components are working correctly
**Why**: We need to ensure everything is functioning before proceeding

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

**What happens**: This verifies that all components are installed and functioning correctly.

## Phase 2 & 3: Scaling Up

After successfully completing Phase 1, you can proceed to larger-scale testing:

### Phase 2: Medium-Scale Testing
- **Cluster**: 10x m5.large nodes (~800 pods capacity)
- **Cost**: ~$423/month
- **Purpose**: Performance testing, scaling validation
- **Follow**: EKS_MIGRATION_GUIDE.md for Phase 2 specifications

### Phase 3: Production-Scale Testing
- **Cluster**: 20+ m5.2xlarge nodes (12,000 pods across 1,425 namespaces)
- **Cost**: ~$2,773/month
- **Purpose**: Production workload validation
- **Follow**: EKS_MIGRATION_GUIDE.md for Phase 3 specifications

## What to Look For

### Phase 1 Success Indicators
- ✅ All 19 test cases pass
- ✅ All pods are running (check with `kubectl get pods -A`)
- ✅ Policy reports are being generated (`kubectl get polr -A`)
- ✅ Grafana dashboard shows metrics
- ✅ No error messages in logs
- ✅ Resource usage within expected limits

### Common Issues and Solutions

**Problem**: AWS credentials not configured
**Solution**: Run `aws configure` and set up your AWS credentials

**Problem**: eksctl not installed
**Solution**: Install with `brew install eksctl`

**Problem**: Cluster creation fails
**Solution**: Check AWS region, permissions, and available resources

**Problem**: Helm charts fail to install
**Solution**: Check internet connection and try `helm repo update`

**Problem**: Pods stuck in pending
**Solution**: Check node resources and cluster capacity

**Problem**: Can't access Grafana
**Solution**: Use port-forward instead of NodePort: `kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80`

## Cleanup

When you're done testing Phase 1:

```bash
# Complete cleanup with options
./phase1-cleanup.sh

# This removes all test resources and gives you options to keep or delete the EKS cluster
```

## Next Steps

After successfully completing Phase 1, you can:

1. **Proceed to Phase 2**: Medium-scale testing (~$423/month)
2. **Proceed to Phase 3**: Production-scale testing (~$2,773/month)
3. **Customize**: Modify policies for your specific needs
4. **Production planning**: Use the metrics to plan resource requirements
5. **SaaS deployment**: Follow the requirements in `reports-server-saas-requirements.md`

## Understanding the Components

### Kyverno n4k
- **What it is**: Enhanced version of Kyverno with additional features
- **What it does**: Checks if your applications follow security policies
- **Why it matters**: Prevents security violations before they happen

### Reports Server
- **What it is**: Separate service for storing policy reports
- **What it does**: Keeps detailed records of all policy violations
- **Why it matters**: Provides audit trail and doesn't overload the main cluster

### Monitoring Stack
- **What it is**: Prometheus + Grafana for metrics and dashboards
- **What it does**: Shows you how well everything is performing
- **Why it matters**: Helps identify problems before they become critical

## Summary

This implementation guide provides a **systematic, phased approach** to testing Kyverno n4k + Reports Server:

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
```

This systematic approach ensures successful testing of Kyverno n4k + Reports Server with comprehensive monitoring and performance analysis.
