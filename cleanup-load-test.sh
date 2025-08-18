#!/bin/bash

echo "🧹 Cleaning up Kyverno n4k + Reports Server Load Test"
echo "=================================================="

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
if ! command_exists kubectl; then
    echo "❌ kubectl is not installed. Please install it first."
    exit 1
fi

if ! command_exists eksctl; then
    echo "❌ eksctl is not installed. Please install it first."
    exit 1
fi

echo "📋 Step 1: Removing test workloads..."
echo "------------------------------------"

# Delete all test namespaces
echo "Deleting 1,425 test namespaces..."
for i in $(seq 1 1425); do
    kubectl delete namespace scale-test-$i --ignore-not-found=true
    if [ $((i % 100)) -eq 0 ]; then
        echo "Deleted $i namespaces"
    fi
done

echo "✅ All test namespaces deleted"

# Wait for namespaces to be fully deleted
echo "⏳ Waiting for namespaces to be fully deleted..."
sleep 30

# Verify cleanup
remaining_namespaces=$(kubectl get namespaces --no-headers | grep scale-test | wc -l)
if [ "$remaining_namespaces" -eq 0 ]; then
    echo "✅ All test namespaces successfully removed"
else
    echo "⚠️  Warning: $remaining_namespaces test namespaces still exist"
    echo "You may need to force delete them manually:"
    echo "kubectl get namespaces | grep scale-test | awk '{print \$1}' | xargs -I {} kubectl delete namespace {} --force --grace-period=0"
fi

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
echo "📋 Step 4: Cleaning up cluster autoscaler..."
echo "-------------------------------------------"

# Delete cluster autoscaler
kubectl delete -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml --ignore-not-found=true
echo "✅ Cluster autoscaler deleted"

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
        echo "aws eks update-kubeconfig --name kyverno-scale-test --region us-west-2"
        ;;
    2)
        echo "🗑️  Deleting EKS cluster..."
        eksctl delete cluster --name kyverno-scale-test --region us-west-2
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
echo "🎉 Cleanup completed!"
echo "===================="
echo ""
echo "If you kept the cluster, you can:"
echo "- Reinstall components for new testing"
echo "- Access it with: aws eks update-kubeconfig --name kyverno-scale-test --region us-west-2"
echo ""
echo "If you deleted the cluster, all resources have been removed."
echo "Costs will stop accruing once the cluster deletion is complete."
