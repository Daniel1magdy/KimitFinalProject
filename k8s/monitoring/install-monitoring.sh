#!/bin/bash 
# k8s/monitoring/install-monitoring.sh

set -e

echo "🔧 Installing Kubernetes Monitoring Stack (Prometheus + Grafana)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed."
    exit 1
fi

if ! command -v helm &> /dev/null; then
    print_error "helm is not installed."
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    print_error "Not connected to a Kubernetes cluster."
    exit 1
fi

print_status "Connected to cluster: $(kubectl config current-context)"

print_status "Checking for StorageClass..."
if ! kubectl get storageclass gp2 &> /dev/null && ! kubectl get storageclass gp3 &> /dev/null; then
    print_warning "No gp2 or gp3 StorageClass found. Creating gp3..."
    cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
EOF
    [ $? -eq 0 ] && print_success "gp3 StorageClass created." || print_warning "Failed to create gp3."
else
    print_success "StorageClass found."
fi

print_status "Creating monitoring namespace..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

print_status "Cleaning up any existing stuck resources..."
kubectl delete pod --all -n monitoring --force --grace-period=0 --ignore-not-found
kubectl delete pvc --all -n monitoring --ignore-not-found

print_status "Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
print_success "Helm repositories added and updated"

helm uninstall prometheus -n monitoring &> /dev/null || true

print_status "Installing Prometheus (no AlertManager, no persistence)..."
helm upgrade --install prometheus prometheus-community/prometheus \
    --namespace monitoring \
    --set server.persistentVolume.enabled=false \
    --set alertmanager.enabled=false \
    --wait \
    --timeout 10m

[ $? -eq 0 ] && print_success "Prometheus installed." || { print_error "Prometheus install failed."; exit 1; }

print_status "Installing Grafana..."
print_status "Creating Grafana admin secret..."
kubectl create secret generic grafana-admin-secret \
  --from-literal=admin-user=admin \
  --from-literal=admin-password=admin123 \
  -n monitoring --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install grafana grafana/grafana \
    --namespace monitoring \
    --values grafana-values.yaml \
    --wait \
    --timeout 10m

[ $? -eq 0 ] && print_success "Grafana installed." || { print_error "Grafana install failed."; exit 1; }

print_status "Waiting for all monitoring pods to be ready..."
kubectl wait --for=condition=ready pod --all -n monitoring --timeout=300s

print_status "Getting service information..."
echo ""
echo "📊 Monitoring Services:"
kubectl get services -n monitoring

echo ""
echo "🔍 Pod Status:"
kubectl get pods -n monitoring

print_status "Retrieving Grafana admin password..."
GRAFANA_PASSWORD=$(kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode)

print_status "Getting external access URLs..."
GRAFANA_LB=$(kubectl get service grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
PROMETHEUS_PORT=$(kubectl get service prometheus-server -n monitoring -o jsonpath='{.spec.ports[0].port}')

echo ""
echo "🎉 Installation Complete!"
echo "========================="
echo "📈 Grafana Dashboard:"
[ ! -z "$GRAFANA_LB" ] && echo "   URL: http://$GRAFANA_LB" || echo "   LoadBalancer pending. Run: kubectl get service grafana -n monitoring"
echo "   Username: admin"
echo "   Password: $GRAFANA_PASSWORD"
echo ""
echo "📊 Prometheus:"
echo "   Access via: kubectl port-forward -n monitoring svc/prometheus-server 9090:80"
echo "   Then visit: http://localhost:9090"
echo ""

print_status "Creating port-forward scripts..."
cat > port-forward-grafana.sh << 'EOF'
#!/bin/bash
echo "Starting Grafana port-forward on http://localhost:3000"
kubectl port-forward -n monitoring svc/grafana 3000:80
EOF

cat > port-forward-prometheus.sh << 'EOF'
#!/bin/bash
echo "Starting Prometheus port-forward on http://localhost:9090"  
kubectl port-forward -n monitoring svc/prometheus-server 9090:80
EOF

chmod +x port-forward-grafana.sh port-forward-prometheus.sh
print_success "Port-forward scripts created."

cat > cleanup-monitoring.sh << 'EOF'
#!/bin/bash
echo "Cleaning up monitoring stack..."
helm uninstall grafana -n monitoring
helm uninstall prometheus -n monitoring
kubectl delete namespace monitoring
echo "Monitoring stack removed!"
EOF

chmod +x cleanup-monitoring.sh
print_success "Cleanup script created."

echo ""
print_success "Monitoring stack installation completed successfully! 🎉"
echo ""
echo "Next steps:"
echo "1. Wait for LoadBalancer to get external IP"
echo "2. Access Grafana and explore dashboards"
echo "3. Import dashboards from https://grafana.com/grafana/dashboards/"
echo "4. Configure alerting via Grafana if needed"
