#!/bin/bash

echo "🧹 Phase 1: Cleanup"
echo "==================="
echo "Cleaning up Phase 1 testing environment"
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

if ! command_exists eksctl; then
    echo "❌ eksctl is not installed"
    exit 1
fi

echo "📋 Step 1: Removing test workloads..."
echo "------------------------------------"

# Remove test pods
echo "Removing test pods..."
kubectl delete pod test-compliant --ignore-not-found=true
kubectl delete pod test-violating --ignore-not-found=true

# Remove test pods created during testing
for i in {1..10}; do
    kubectl delete pod test-pod-$i --ignore-not-found=true
done

echo "✅ Test pods removed"

echo ""
echo "📋 Step 2: Removing Kyverno and Reports Server..."
echo "------------------------------------------------"

# Delete Kyverno and Reports Server
kubectl delete namespace kyverno --ignore-not-found=true
echo "✅ Kyverno namespace deleted"

echo ""
echo "📋 Step 3: Removing monitoring stack..."
echo "--------------------------------------"

# Delete monitoring stack
kubectl delete namespace monitoring --ignore-not-found=true
echo "✅ Monitoring namespace deleted"

echo ""
echo "📋 Step 4: Removing policies..."
echo "-------------------------------"

# Remove policies
kubectl delete -f kyverno-policies/pod-security/baseline --ignore-not-found=true 2>/dev/null || echo "Policies already removed"

echo ""
echo "📋 Step 5: Verifying cleanup..."
echo "-------------------------------"

# Check remaining resources
echo "Remaining namespaces:"
kubectl get namespaces

echo ""
echo "Remaining pods:"
kubectl get pods -A

echo ""
echo "📋 Step 6: Cluster cleanup options..."
echo "------------------------------------"

echo "Choose an option:"
echo "1) Keep the EKS cluster (for future testing)"
echo "2) Delete the entire EKS cluster (cost saving)"
echo "3) Exit without deleting cluster"

read -p "Enter your choice (1-3): " choice

case $choice in
    1)
        echo "✅ EKS cluster will be kept. You can access it with:"
        echo "aws eks update-kubeconfig --name kyverno-test-phase1 --region us-west-2"
        ;;
    2)
        echo "🗑️  Deleting EKS cluster..."
        eksctl delete cluster --name kyverno-test-phase1 --region us-west-2
        echo "✅ EKS cluster deleted"
        ;;
    3)
        echo "✅ Exiting. Cluster remains available."
        ;;
    *)
        echo "❌ Invalid choice. Exiting without deleting cluster."
        ;;
esac

echo ""
echo "📋 Step 7: Saving monitoring data..."
echo "-----------------------------------"

# Save monitoring data if it exists
if [ -d "phase1-monitoring-data" ]; then
    echo "Monitoring data found in phase1-monitoring-data/"
    echo "Consider saving this data for analysis before cleanup"
    
    read -p "Do you want to keep the monitoring data? (y/n): " keep_data
    
    if [ "$keep_data" != "y" ]; then
        rm -rf phase1-monitoring-data
        echo "✅ Monitoring data removed"
    else
        echo "✅ Monitoring data preserved"
    fi
fi

echo ""
echo "🎉 Phase 1 Cleanup Completed!"
echo "============================="
echo ""
echo "📊 Phase 1 Summary:"
echo "- Validated basic EKS deployment"
echo "- Tested Kyverno n4k installation"
echo "- Verified Reports Server integration"
echo "- Confirmed monitoring stack functionality"
echo "- Established baseline performance metrics"
echo ""
echo "📋 Next Steps:"
echo "1. Analyze test results and monitoring data"
echo "2. Document findings and requirements"
echo "3. Plan Phase 2 with updated specifications"
echo "4. Proceed to Phase 2 when ready"
echo ""
echo "💡 Phase 1 provided valuable insights for scaling to production workloads."
