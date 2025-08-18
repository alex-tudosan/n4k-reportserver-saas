#!/bin/bash

echo "=== Kyverno n4k + Reports Server Load Test Monitor ==="
echo "Monitoring 12,000 pods across 1,425 namespaces"
echo "=================================================="

while true; do
    clear
    echo "=== $(date) ==="
    echo ""
    
    # Cluster status
    echo "📊 CLUSTER STATUS:"
    echo "------------------"
    echo "Nodes: $(kubectl get nodes --no-headers | wc -l)"
    echo "Namespaces: $(kubectl get namespaces --no-headers | grep scale-test | wc -l)"
    echo "Pods: $(kubectl get pods -A --no-headers | grep scale-test | wc -l)"
    echo "Running Pods: $(kubectl get pods -A --no-headers | grep scale-test | grep Running | wc -l)"
    echo "Pending Pods: $(kubectl get pods -A --no-headers | grep scale-test | grep Pending | wc -l)"
    echo "Failed Pods: $(kubectl get pods -A --no-headers | grep scale-test | grep Failed | wc -l)"
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
    
    # Performance metrics
    echo "⚡ PERFORMANCE METRICS:"
    echo "----------------------"
    echo "Kyverno Admission Requests (last 5m):"
    kubectl -n monitoring exec -it $(kubectl -n monitoring get pods -l app=prometheus -o jsonpath='{.items[0].metadata.name}') -- curl -s 'http://localhost:9090/api/v1/query?query=rate(kyverno_admission_requests_total[5m])' | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "N/A"
    echo ""
    echo "Reports Server API Requests (last 5m):"
    kubectl -n monitoring exec -it $(kubectl -n monitoring get pods -l app=prometheus -o jsonpath='{.items[0].metadata.name}') -- curl -s 'http://localhost:9090/api/v1/query?query=rate(apiserver_request_duration_seconds_count{group=~"reports.kyverno.io|wgpolicyk8s.io"}[5m])' | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "N/A"
    echo ""
    
    # Recent events
    echo "📝 RECENT EVENTS (last 10):"
    echo "---------------------------"
    kubectl get events --sort-by='.lastTimestamp' --no-headers | tail -10
    echo ""
    
    echo "Press Ctrl+C to stop monitoring..."
    sleep 30
done
