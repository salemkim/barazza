#!/bin/bash
set -e

ENV=${1:-production}
IMAGE_TAG=${2:-latest}
REGION=ap-southeast-1
ACCOUNT_ID=${3:-YOUR_ACCOUNT_ID}

echo "🚀 Starting Baraza deployment for environment: $ENV"

if [ "$ACCOUNT_ID" = "YOUR_ACCOUNT_ID" ]; then
  echo "❌ Error: ACCOUNT_ID not set. Usage: ./deploy.sh <env> <tag> <account-id>"
  exit 1
fi

echo "📦 Building Docker image..."
docker build -t baraza:${IMAGE_TAG} .

echo "🏷️  Tagging image for Huawei registry..."
REGISTRY_URL="${ACCOUNT_ID}.dkr.${REGION}.huaweicloud.com"
docker tag baraza:${IMAGE_TAG} ${REGISTRY_URL}/baraza/app:${IMAGE_TAG}
docker tag baraza:${IMAGE_TAG} ${REGISTRY_URL}/baraza/app:latest

echo "🔐 Logging in to Huawei registry..."
echo "${REGISTRY_PASSWORD}" | docker login -u ${REGISTRY_USER} --password-stdin ${REGISTRY_URL}

echo "📤 Pushing image to registry..."
docker push ${REGISTRY_URL}/baraza/app:${IMAGE_TAG}
docker push ${REGISTRY_URL}/baraza/app:latest

echo "🔧 Configuring kubectl..."
export KUBECONFIG=~/kubeconfig.json

echo "☸️  Updating deployment..."
kubectl set image deployment/baraza-app \
  baraza=${REGISTRY_URL}/baraza/app:${IMAGE_TAG} \
  -n baraza-prod

echo "⏳ Waiting for deployment rollout..."
kubectl rollout status deployment/baraza-app -n baraza-prod --timeout=5m

echo "✅ Verifying deployment..."
kubectl get deployments -n baraza-prod
kubectl get pods -n baraza-prod

echo "✨ Deployment completed successfully!"
