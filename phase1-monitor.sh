#!/bin/bash

echo "📊 Phase 1: Performance Monitoring"
echo "=================================="
echo "Monitoring Kyverno n4k + Reports Server performance"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
if ! command_exists kubectl; then
    echo "❌ kubectl is not installed"
    exit 1
fi

# Create monitoring directory
mkdir -p phase1-monitoring-data

echo "📋 Starting performance monitoring..."
echo "Press Ctrl+C to stop monitoring"
echo ""

# Initialize counters
iteration=0

while true; do
    clear
    echo "=== Phase 1 Performance Monitoring - $(date) ==="
    echo "Iteration: $iteration"
    echo ""
    
    # Cluster status
    echo "📊 CLUSTER STATUS:"
    echo "------------------"
    echo "Nodes: $(kubectl get nodes --no-headers | wc -l)"
    echo "Total Pods: $(kubectl get pods -A --no-headers | wc -l)"
    echo "Running Pods: $(kubectl get pods -A --no-headers | grep Running | wc -l)"
    echo "Pending Pods: $(kubectl get pods -A --no-headers | grep Pending | wc -l)"
    echo "Failed Pods: $(kubectl get pods -A --no-headers | grep Failed | wc -l)"
    echo ""
    
    # Kyverno status
    echo "🛡️  KYVERNO STATUS:"
    echo "------------------"
    echo "Kyverno Pods: $(kubectl -n kyverno get pods -l app.kubernetes.io/part-of=kyverno --no-headers | wc -l)"
    echo "Kyverno Ready: $(kubectl -n kyverno get pods -l app.kubernetes.io/part-of=kyverno --no-headers | grep Running | wc -l)"
    echo "Policy Reports: $(kubectl get polr -A --no-headers | wc -l)"
    echo "Cluster Policy Reports: $(kubectl get cpolr --no-headers | wc -l)"
    echo ""
    
    # Reports Server status
    echo "📋 REPORTS SERVER STATUS:"
    echo "-------------------------"
    echo "Reports Server Pods: $(kubectl -n kyverno get pods -l app.kubernetes.io/name=reports-server --no-headers | wc -l)"
    echo "Reports Server Ready: $(kubectl -n kyverno get pods -l app.kubernetes.io/name=reports-server --no-headers | grep Running | wc -l)"
    echo "etcd Pods: $(kubectl -n kyverno get pods -l app=etcd-reports-server --no-headers | wc -l)"
    echo "etcd Ready: $(kubectl -n kyverno get pods -l app=etcd-reports-server --no-headers | grep Running | wc -l)"
    echo ""
    
    # Resource usage
    echo "💾 RESOURCE USAGE:"
    echo "-----------------"
    echo "Node CPU Usage:"
    kubectl top nodes --no-headers | head -5
    echo ""
    echo "Node Memory Usage:"
    kubectl top nodes --no-headers | tail -5
    echo ""
    
    # Pod resource usage
    echo "Pod Resource Usage (Top 10):"
    kubectl top pods -A --no-headers | head -10
    echo ""
    
    # Performance metrics (if Prometheus is available)
    echo "⚡ PERFORMANCE METRICS:"
    echo "----------------------"
    
    # Try to get Kyverno admission requests rate
    if kubectl -n monitoring get pods -l app=prometheus --no-headers | grep -q Running; then
        echo "Kyverno Admission Requests (last 5m):"
        kubectl -n monitoring exec -it $(kubectl -n monitoring get pods -l app=prometheus -o jsonpath='{.items[0].metadata.name}') -- curl -s 'http://localhost:9090/api/v1/query?query=rate(kyverno_admission_requests_total[5m])' 2>/dev/null | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "N/A"
        echo ""
        
        echo "Reports Server API Requests (last 5m):"
        kubectl -n monitoring exec -it $(kubectl -n monitoring get pods -l app=prometheus -o jsonpath='{.items[0].metadata.name}') -- curl -s 'http://localhost:9090/api/v1/query?query=rate(apiserver_request_duration_seconds_count{group=~"reports.kyverno.io|wgpolicyk8s.io"}[5m])' 2>/dev/null | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "N/A"
        echo ""
    else
        echo "Prometheus not available for metrics"
        echo ""
    fi
    
    # etcd storage info
    echo "🗄️  ETCD STORAGE:"
    echo "----------------"
    if kubectl -n kyverno get pods -l app=etcd-reports-server --no-headers | grep -q Running; then
        echo "etcd Status:"
        kubectl -n kyverno exec etcd-0 -c etcd -- etcdctl endpoint status --write-out=table 2>/dev/null | head -3 || echo "Unable to get etcd status"
        echo ""
    else
        echo "etcd not available"
        echo ""
    fi
    
    # Recent events
    echo "📝 RECENT EVENTS (last 5):"
    echo "---------------------------"
    kubectl get events --sort-by='.lastTimestamp' --no-headers | tail -5
    echo ""
    
    # Save data to file
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp,$(kubectl get pods -A --no-headers | wc -l),$(kubectl get polr -A --no-headers | wc -l),$(kubectl top nodes --no-headers | awk '{sum+=$3} END {print sum/NR}'),$(kubectl top nodes --no-headers | awk '{sum+=$5} END {print sum/NR}')" >> phase1-monitoring-data/resource-usage.csv
    
    # Create CSV header if file is new
    if [ ! -f phase1-monitoring-data/resource-usage.csv ] || [ ! -s phase1-monitoring-data/resource-usage.csv ]; then
        echo "Timestamp,Total_Pods,Policy_Reports,Avg_CPU_%,Avg_Memory_%" > phase1-monitoring-data/resource-usage.csv
    fi
    
    echo "Press Ctrl+C to stop monitoring..."
    echo "Data saved to: phase1-monitoring-data/resource-usage.csv"
    echo ""
    
    sleep 30
    ((iteration++))
done
