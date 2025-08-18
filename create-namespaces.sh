#!/bin/bash

echo "Creating 1,425 namespaces..."

for i in $(seq 1 1425); do
  kubectl create namespace scale-test-$i
  if [ $((i % 100)) -eq 0 ]; then
    echo "Created $i namespaces"
  fi
done

echo "All namespaces created!"
