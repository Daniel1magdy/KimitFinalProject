#!/bin/bash
echo "Starting Prometheus port-forward on http://localhost:9090"  
kubectl port-forward -n monitoring svc/prometheus-server 9090:80
