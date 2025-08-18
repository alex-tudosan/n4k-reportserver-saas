#!/bin/bash

echo "🧪 Phase 1: Test Cases Execution"
echo "================================"
echo "Running comprehensive test cases for Kyverno n4k + Reports Server"
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

# Test counter
tests_passed=0
tests_failed=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"
    
    echo "🔍 Running: $test_name"
    echo "Command: $test_command"
    
    # Run the test command
    if eval "$test_command" >/dev/null 2>&1; then
        echo "✅ PASS: $test_name"
        ((tests_passed++))
    else
        echo "❌ FAIL: $test_name"
        echo "Expected: $expected_result"
        ((tests_failed++))
    fi
    echo ""
}

echo "📋 Test Category 1: Basic Functionality Tests"
echo "============================================="

# Test 1: Kyverno n4k installation
run_test "Kyverno n4k pods are running" \
    "kubectl -n kyverno get pods -l app.kubernetes.io/part-of=kyverno --no-headers | grep -q Running" \
    "Kyverno pods should be in Running state"

# Test 2: Reports Server installation
run_test "Reports Server pods are running" \
    "kubectl -n kyverno get pods -l app.kubernetes.io/name=reports-server --no-headers | grep -q Running" \
    "Reports Server pods should be in Running state"

# Test 3: etcd pods are running
run_test "etcd pods are running" \
    "kubectl -n kyverno get pods -l app=etcd-reports-server --no-headers | grep -q Running" \
    "etcd pods should be in Running state"

# Test 4: Monitoring stack is running
run_test "Prometheus pods are running" \
    "kubectl -n monitoring get pods -l app=prometheus --no-headers | grep -q Running" \
    "Prometheus pods should be in Running state"

# Test 5: Grafana is running
run_test "Grafana pods are running" \
    "kubectl -n monitoring get pods -l app.kubernetes.io/name=grafana --no-headers | grep -q Running" \
    "Grafana pods should be in Running state"

echo "📋 Test Category 2: Policy Enforcement Tests"
echo "============================================"

# Test 6: Policies are installed
run_test "Baseline policies are installed" \
    "kubectl get policies -A --no-headers | wc -l | grep -q -E '[1-9]'" \
    "At least one policy should be installed"

# Test 7: Create a compliant pod
run_test "Compliant pod creation" \
    "kubectl run test-compliant --image=nginx:alpine --restart=Never --dry-run=client -o yaml | kubectl apply -f -" \
    "Compliant pod should be created successfully"

# Test 8: Create a violating pod
run_test "Policy violation detection" \
    "kubectl run test-violating --image=nginx:alpine --restart=Never --privileged --dry-run=client -o yaml | kubectl apply -f - 2>&1 | grep -q 'denied'" \
    "Violating pod should be denied"

# Test 9: Policy reports generation
run_test "Policy reports are generated" \
    "sleep 10 && kubectl get polr -A --no-headers | wc -l | grep -q -E '[0-9]'" \
    "Policy reports should be generated"

echo "📋 Test Category 3: Monitoring Tests"
echo "===================================="

# Test 10: ServiceMonitors are configured
run_test "ServiceMonitors are created" \
    "kubectl -n monitoring get servicemonitors --no-headers | wc -l | grep -q -E '[1-9]'" \
    "ServiceMonitors should be configured"

# Test 11: Prometheus targets are up
run_test "Prometheus targets are healthy" \
    "kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 & sleep 5 && curl -s http://localhost:9090/api/v1/targets | grep -q 'up' && kill %1" \
    "Prometheus targets should be up"

# Test 12: Grafana is accessible
run_test "Grafana is accessible" \
    "kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80 & sleep 5 && curl -s http://localhost:3000 | grep -q 'Grafana' && kill %1" \
    "Grafana should be accessible"

echo "📋 Test Category 4: Performance Tests"
echo "====================================="

# Test 13: Pod creation rate
echo "🔍 Testing: Pod creation rate"
start_time=$(date +%s)
for i in {1..10}; do
    kubectl run test-pod-$i --image=nginx:alpine --restart=Never --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1
done
end_time=$(date +%s)
creation_time=$((end_time - start_time))
if [ $creation_time -lt 30 ]; then
    echo "✅ PASS: Pod creation rate (10 pods in ${creation_time}s)"
    ((tests_passed++))
else
    echo "❌ FAIL: Pod creation rate (took ${creation_time}s, expected <30s)"
    ((tests_failed++))
fi
echo ""

# Test 14: Resource usage check
run_test "Resource usage is within limits" \
    "kubectl top nodes --no-headers | awk '{if(\$3 > 80 || \$5 > 80) exit 1}'" \
    "Node resource usage should be below 80%"

echo "📋 Test Category 5: etcd Storage Tests"
echo "======================================"

# Test 15: etcd storage functionality
run_test "etcd storage is accessible" \
    "kubectl -n kyverno exec etcd-0 -c etcd -- etcdctl endpoint status --write-out=table" \
    "etcd should be accessible and healthy"

# Test 16: etcd metrics are available
run_test "etcd metrics are exposed" \
    "kubectl -n kyverno port-forward svc/reports-server-etcd 2379:2379 & sleep 3 && curl -s http://localhost:2379/metrics | grep -q 'etcd_' && kill %1" \
    "etcd metrics should be exposed"

echo "📋 Test Category 6: API Functionality Tests"
echo "==========================================="

# Test 17: Kyverno API is responsive
run_test "Kyverno API is responsive" \
    "kubectl get policies -A --request-timeout=10s" \
    "Kyverno API should respond within 10 seconds"

# Test 18: Reports Server API is responsive
run_test "Reports Server API is responsive" \
    "kubectl get polr -A --request-timeout=10s" \
    "Reports Server API should respond within 10 seconds"

echo "📋 Test Category 7: Failure Recovery Tests"
echo "=========================================="

# Test 19: Pod restart recovery
echo "🔍 Testing: Pod restart recovery"
kubectl -n kyverno delete pod $(kubectl -n kyverno get pods -l app.kubernetes.io/part-of=kyverno -o jsonpath='{.items[0].metadata.name}') >/dev/null 2>&1
sleep 30
if kubectl -n kyverno get pods -l app.kubernetes.io/part-of=kyverno --no-headers | grep -q Running; then
    echo "✅ PASS: Pod restart recovery"
    ((tests_passed++))
else
    echo "❌ FAIL: Pod restart recovery"
    ((tests_failed++))
fi
echo ""

echo "📋 Test Results Summary"
echo "======================="
echo "Total Tests: $((tests_passed + tests_failed))"
echo "✅ Passed: $tests_passed"
echo "❌ Failed: $tests_failed"
echo ""

if [ $tests_failed -eq 0 ]; then
    echo "🎉 All tests passed! Phase 1 validation successful."
    echo ""
    echo "📋 Next Steps:"
    echo "1. Run performance monitoring: ./phase1-monitor.sh"
    echo "2. Document findings for Phase 2 planning"
    echo "3. Proceed to Phase 2 when ready"
else
    echo "⚠️  Some tests failed. Please investigate before proceeding."
    echo ""
    echo "📋 Troubleshooting:"
    echo "1. Check pod logs: kubectl logs -n kyverno -l app.kubernetes.io/part-of=kyverno"
    echo "2. Check events: kubectl get events --sort-by='.lastTimestamp'"
    echo "3. Check resource usage: kubectl top nodes && kubectl top pods -A"
fi

echo ""
echo "📊 Resource Usage Summary:"
echo "-------------------------"
echo "Nodes:"
kubectl top nodes
echo ""
echo "Pods by namespace:"
kubectl get pods -A --no-headers | awk '{print $1}' | sort | uniq -c
echo ""
echo "Storage usage:"
kubectl get pvc -A
