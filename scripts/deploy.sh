#!/usr/bin/env bash
# Deploy NIM + GPU monitoring stack onto an existing EKS cluster.
# Usage: ./deploy.sh <NGC_API_KEY>
set -euo pipefail

NGC_KEY="${1:?Usage: ./deploy.sh <NGC_API_KEY>}"

echo "=== 1/4  Creating NGC image pull secret ==="
kubectl create secret docker-registry ngc-secret \
  --docker-server=nvcr.io \
  --docker-username='$oauthtoken' \
  --docker-password="${NGC_KEY}" \
  --dry-run=client -o yaml | kubectl apply -f -

# Also store the key so NIM can download model weights at runtime
kubectl create secret generic ngc-secret \
  --from-literal=NGC_API_KEY="${NGC_KEY}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "=== 2/4  Installing NVIDIA DCGM Exporter (GPU metrics) ==="
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia --force-update
helm upgrade --install dcgm-exporter nvidia/dcgm-exporter \
  --namespace monitoring --create-namespace \
  --set tolerations[0].key=nvidia.com/gpu \
  --set tolerations[0].operator=Exists \
  --set tolerations[0].effect=NoSchedule

echo "=== 3/4  Installing Prometheus + Adapter (metrics pipeline for HPA) ==="
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update

# Prometheus — scrape DCGM metrics
helm upgrade --install prometheus prometheus-community/prometheus \
  --namespace monitoring --create-namespace \
  --set server.persistentVolume.enabled=false \
  --set alertmanager.enabled=false

# Prometheus Adapter — expose DCGM metrics to Kubernetes HPA
helm upgrade --install prometheus-adapter prometheus-community/prometheus-adapter \
  --namespace monitoring \
  --set prometheus.url=http://prometheus-server.monitoring.svc \
  --set prometheus.port=80 \
  --set "rules.custom[0].seriesQuery=DCGM_FI_DEV_GPU_UTIL" \
  --set "rules.custom[0].metricsQuery=avg(<<.Series>>{<<.LabelMatchers>>}) by (<<.GroupBy>>)" \
  --set "rules.custom[0].resources.overrides.namespace.resource=namespace" \
  --set "rules.custom[0].resources.overrides.pod.resource=pod"

echo "=== 4/4  Deploying NIM ==="
kubectl apply -f k8s/

echo ""
echo "Done! NIM is starting (TensorRT engine build takes ~2-5 min on first boot)."
echo "Watch progress:  kubectl logs -f deployment/nim-llm"
echo "Check HPA:       kubectl get hpa nim-llm -w"
echo "Get endpoint:    kubectl get svc nim-llm -w"
