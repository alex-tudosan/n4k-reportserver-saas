# Quick Start Reference Card

## 🚀 One-Command Setup (After Prerequisites)

```bash
# 1. Start Docker and wait 30 seconds
open -a Docker && sleep 30

# 2. Create cluster
kind create cluster --config kind-config.yaml --wait 600s

# 3. Install monitoring
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  --set grafana.service.type=NodePort --set grafana.service.nodePort=30001 \
  --set prometheus.service.type=NodePort --set prometheus.service.nodePort=30000

# 4. Install Reports Server
helm repo add rs https://nirmata.github.io/reports-server/
helm upgrade --install reports-server rs/reports-server \
  --namespace kyverno --create-namespace --version 0.2.3

# 5. Install Kyverno n4k
helm repo add nirmata https://nirmata.github.io/kyverno-charts/
helm upgrade --install kyverno nirmata/kyverno \
  --namespace kyverno --create-namespace --version 3.4.7

# 6. Setup monitoring
kubectl apply -f reports-server-servicemonitor.yaml
kubectl apply -f kyverno-servicemonitor.yaml
kubectl apply -f reports-server-etcd-servicemonitor.yaml

# 7. Install policies
git clone --depth 1 https://github.com/nirmata/kyverno-policies.git
kubectl kustomize kyverno-policies/pod-security/baseline | kubectl apply -f -

# 8. Test
kubectl apply -f baseline-violations-pod.yaml
kubectl get polr -A
```

## 🔑 Access Credentials

```bash
# Get Grafana password
kubectl -n monitoring get secret monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d ; echo

# Access URLs
echo "Grafana: http://localhost:30001 (admin/[password])"
echo "Prometheus: http://localhost:30000"
```

## ✅ Verification Commands

```bash
# Check all components are running
kubectl get pods -A

# Check policies are active
kubectl get policies -A

# Check reports are being generated
kubectl get polr -A

# Check monitoring is working
kubectl -n monitoring get servicemonitors
```

## 🧹 Cleanup

```bash
kind delete cluster --name kyverno-reports-test
```

## 📊 What You'll See

- **Grafana Dashboard**: Import `kyverno-dashboard.json` for comprehensive metrics
- **Policy Reports**: View violations at `kubectl get polr -A`
- **Performance Metrics**: Monitor latency, throughput, and resource usage
- **Storage Monitoring**: Track etcd usage for both Kubernetes and Reports Server

## 🆘 Quick Troubleshooting

| Problem | Solution |
|---------|----------|
| Docker not running | `open -a Docker && sleep 30` |
| Helm fails | `helm repo update` |
| Pods pending | Check Docker resources |
| Can't access Grafana | Check port 30001 isn't blocked |
| No reports | Wait 1-2 minutes for policies to activate |
