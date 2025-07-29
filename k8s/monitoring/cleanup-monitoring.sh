#!/bin/bash
echo "Cleaning up monitoring stack..."
helm uninstall grafana -n monitoring
helm uninstall prometheus -n monitoring
kubectl delete namespace monitoring
echo "Monitoring stack removed!"
