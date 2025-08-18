# Kyverno n4k + Reports Server Implementation Guide

## What This Demo Does

This demo sets up a complete testing environment for **Kyverno n4k** (an enhanced version of Kyverno) with a **Reports Server** that stores policy reports separately from the main Kubernetes cluster. It includes monitoring tools to watch how everything performs.

**Think of it like this**: 
- Kyverno = Security guard that checks if your applications follow rules
- Reports Server = Filing cabinet that keeps detailed records of what the security guard found
- Monitoring = Dashboard that shows you how well everything is working

## Prerequisites

Before starting, make sure you have these tools installed:

```bash
# Check if you have the required tools
which kind kubectl helm jq

# If any are missing, install them:
# For macOS:
brew install kind kubectl helm jq

# For Linux:
# Follow installation guides for each tool
```

## Step-by-Step Implementation

### Step 1: Prepare Your Environment

**What we're doing**: Making sure Docker is running and we're in the right directory
**Why**: Docker is needed to create the test cluster, and we need to be in the project directory

```bash
# Start Docker (if not already running)
open -a Docker  # macOS
# or
sudo systemctl start docker  # Linux

# Wait for Docker to fully start (about 30 seconds)
# Then verify it's working:
docker ps
```

### Step 2: Create the Test Cluster

**What we're doing**: Creating a local Kubernetes cluster for safe testing
**Why**: We need a safe environment to test Kyverno without affecting real workloads

```bash
# Create a 3-node cluster (1 control plane + 2 workers)
kind create cluster --config kind-config.yaml --wait 600s

# Verify the cluster is working
kubectl get nodes
```

**What happens**: This creates a small Kubernetes cluster running in Docker containers on your machine.

### Step 3: Install Monitoring Tools

**What we're doing**: Installing Prometheus and Grafana to watch our system
**Why**: We need to see how Kyverno and the Reports Server are performing

```bash
# Add the Prometheus chart repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus + Grafana
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  --set grafana.enabled=true \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30001 \
  --set prometheus.service.type=NodePort \
  --set prometheus.service.nodePort=30000

# Wait for all pods to be ready
kubectl -n monitoring wait --for=condition=ready pod -l app.kubernetes.io/name=grafana --timeout=300s
```

**What happens**: This installs Prometheus (collects metrics) and Grafana (shows dashboards) in a namespace called "monitoring".

### Step 4: Get Grafana Access

**What we're doing**: Getting the password to access the Grafana dashboard
**Why**: You'll need this to view the monitoring dashboards later

```bash
# Get the Grafana admin password
kubectl -n monitoring get secret monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d ; echo

# Note down this password - you'll need it later
# Default username is: admin
```

### Step 5: Install the Reports Server

**What we're doing**: Installing the component that stores policy reports separately
**Why**: This keeps policy reports in a dedicated storage system, separate from the main Kubernetes database

```bash
# Add the Reports Server chart repository
helm repo add rs https://nirmata.github.io/reports-server/
helm repo update

# Install Reports Server (MUST be installed BEFORE Kyverno)
helm upgrade --install reports-server rs/reports-server \
  --namespace kyverno --create-namespace \
  --version 0.2.3

# Wait for it to be ready
kubectl -n kyverno wait --for=condition=ready pod -l app.kubernetes.io/name=reports-server --timeout=300s
```

**What happens**: This installs a service that will store all the policy violation reports in its own database.

### Step 6: Install Kyverno n4k

**What we're doing**: Installing the enhanced version of Kyverno
**Why**: This is the main policy engine that will check your applications against security rules

```bash
# Add the Nirmata chart repository
helm repo add nirmata https://nirmata.github.io/kyverno-charts/
helm repo update

# Install Kyverno n4k
helm upgrade --install kyverno nirmata/kyverno \
  --namespace kyverno --create-namespace \
  --version 3.4.7

# Wait for Kyverno to be ready
kubectl -n kyverno wait --for=condition=ready pod -l app.kubernetes.io/part-of=kyverno --timeout=300s
```

**What happens**: This installs Kyverno, which will start watching your cluster for policy violations.

### Step 7: Set Up Monitoring

**What we're doing**: Telling Prometheus to collect metrics from Kyverno and Reports Server
**Why**: Without this, we won't be able to see how the system is performing

```bash
# Apply ServiceMonitors to enable metrics collection
kubectl apply -f reports-server-servicemonitor.yaml
kubectl apply -f kyverno-servicemonitor.yaml
kubectl apply -f reports-server-etcd-servicemonitor.yaml

# Verify ServiceMonitors are created
kubectl -n monitoring get servicemonitors
```

**What happens**: This creates "watchers" that tell Prometheus to collect performance data from Kyverno and the Reports Server.

### Step 8: Install Sample Policies

**What we're doing**: Installing some basic security policies to test the system
**Why**: We need policies to test against - these are like security rules that Kyverno will enforce

```bash
# Clone the policies repository
test -d kyverno-policies || git clone --depth 1 https://github.com/nirmata/kyverno-policies.git

# Apply baseline Pod Security policies
kubectl kustomize kyverno-policies/pod-security/baseline | kubectl apply -f -
```

**What happens**: This installs a set of basic security policies that will check if pods are running securely.

### Step 9: Test the System

**What we're doing**: Creating some test workloads to see if the policies are working
**Why**: We need to verify that everything is working correctly

```bash
# Check if policies are active
kubectl get policies -A

# Create a test pod that violates policies
kubectl apply -f baseline-violations-pod.yaml

# Check for policy reports
kubectl get polr -A

# Test ClusterPolicyReports
kubectl apply -f cpolr-demo.yaml
kubectl get cpolr
```

**What happens**: This creates a pod that intentionally violates security policies, so you can see how Kyverno responds and generates reports.

### Step 10: Access the Dashboards

**What we're doing**: Opening the monitoring dashboards to see the system in action
**Why**: This is where you'll see all the metrics and understand how the system is performing

```bash
# Access Grafana (open in your browser)
echo "Grafana URL: http://localhost:30001"
echo "Username: admin"
echo "Password: (use the password from Step 4)"

# Access Prometheus (open in your browser)
echo "Prometheus URL: http://localhost:30000"
```

**To import the Kyverno dashboard**:
1. Go to Grafana (http://localhost:30001)
2. Login with admin and your password
3. Go to Dashboards → Import
4. Upload the `kyverno-dashboard.json` file from this repository
5. Select your Prometheus data source
6. Click Import

### Step 11: Load Testing (Optional)

**What we're doing**: Creating many test workloads to see how the system performs under load
**Why**: This helps understand how the system will behave in a real production environment

```bash
# Create 100 test namespaces
for i in $(seq 1 100); do kubectl create ns lt-$i; done

# Create a violating pod in each namespace
for i in $(seq 1 100); do kubectl -n lt-$i apply -f baseline-violations-pod.yaml; done

# Check the load on the system
kubectl get polr -A | wc -l
```

**What happens**: This creates a lot of policy violations to test how well the system handles high load.

### Step 12: Monitor Performance

**What we're doing**: Checking various metrics to understand system performance
**Why**: This helps identify any performance issues or bottlenecks

```bash
# Check etcd storage usage (Kubernetes control plane)
ETCD_POD=$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}')
kubectl -n kube-system exec $ETCD_POD -- sh -c "ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/peer.crt --key=/etc/kubernetes/pki/etcd/peer.key endpoint status --write-out=table"

# Check Reports Server etcd storage
kubectl -n kyverno exec etcd-0 -c etcd -- etcdctl endpoint status --write-out=table
```

## What to Look For

### Success Indicators
- ✅ All pods are running (check with `kubectl get pods -A`)
- ✅ Policy reports are being generated (`kubectl get polr -A`)
- ✅ Grafana dashboard shows metrics
- ✅ No error messages in logs

### Common Issues and Solutions

**Problem**: Docker not running
**Solution**: Start Docker and wait 30 seconds before creating the cluster

**Problem**: Helm charts fail to install
**Solution**: Check internet connection and try `helm repo update`

**Problem**: Pods stuck in pending
**Solution**: Check if Docker has enough resources allocated

**Problem**: Can't access Grafana
**Solution**: Verify the NodePort is working and check if any firewall is blocking port 30001

## Cleanup

When you're done testing:

```bash
# Delete the entire cluster
kind delete cluster --name kyverno-reports-test

# This removes everything - the cluster, all data, and monitoring
```

## Next Steps

Once you have this working locally, you can:

1. **Scale up**: Test with more policies and workloads
2. **Customize**: Modify policies for your specific needs
3. **Production planning**: Use the metrics to plan resource requirements
4. **SaaS deployment**: Follow the requirements in `reports-server-saas-requirements.md`

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

This setup gives you a complete, production-ready testing environment for understanding how Kyverno works with enhanced reporting capabilities.
