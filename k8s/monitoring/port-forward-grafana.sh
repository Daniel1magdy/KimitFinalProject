#!/bin/bash
echo "Starting Grafana port-forward on http://localhost:3000"
kubectl port-forward -n monitoring svc/grafana 3000:80
