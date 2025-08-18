#!/bin/bash

echo "Creating 12,000 pods across 1,425 namespaces..."

# Calculate pods per namespace (approximately 8.4 pods per namespace)
pods_per_namespace=8
extra_pods=12000

for i in $(seq 1 1425); do
  namespace="scale-test-$i"
  
  # Create base pods for this namespace
  for j in $(seq 1 $pods_per_namespace); do
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-pod-$j
  namespace: $namespace
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
      limits:
        memory: "128Mi"
        cpu: "100m"
  restartPolicy: Never
EOF
  done
  
  # Create some violating pods for policy testing
  if [ $((i % 10)) -eq 0 ]; then
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: violating-pod
  namespace: $namespace
spec:
  hostPID: true
  containers:
  - name: nginx
    image: nginx:alpine
    securityContext:
      privileged: true
EOF
  fi
  
  if [ $((i % 100)) -eq 0 ]; then
    echo "Created pods in $i namespaces"
  fi
done

echo "All pods created!"
