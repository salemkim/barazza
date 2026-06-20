#!/bin/bash
set -e

echo "🔐 Setting up Kubernetes secrets for Baraza..."

NAMESPACE="baraza-prod"
echo "Namespace: $NAMESPACE"

echo "📦 Creating namespace if needed..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

echo "📊 Setting up database credentials..."
read -p "Enter DATABASE_URL (postgresql://...): " DB_URL
kubectl create secret generic db-credentials \
  --from-literal=DATABASE_URL="$DB_URL" \
  -n $NAMESPACE \
  --dry-run=client -o yaml | kubectl apply -f -

echo "☁️  Setting up OBS credentials..."
read -p "Enter OBS_ACCESS_KEY: " OBS_KEY
read -sp "Enter OBS_SECRET_KEY: " OBS_SECRET
echo
read -p "Enter OBS_REGION (e.g., ap-southeast-1): " OBS_REGION
read -p "Enter OBS_BUCKET (e.g., baraza-uploads-xxx): " OBS_BUCKET

kubectl create secret generic obs-credentials \
  --from-literal=OBS_ACCESS_KEY="$OBS_KEY" \
  --from-literal=OBS_SECRET_KEY="$OBS_SECRET" \
  --from-literal=OBS_REGION="$OBS_REGION" \
  --from-literal=OBS_BUCKET="$OBS_BUCKET" \
  -n $NAMESPACE \
  --dry-run=client -o yaml | kubectl apply -f -

echo "🔑 Setting up application secrets..."
JWT_SECRET=$(openssl rand -base64 32)

read -p "Enter AT_API_KEY (Africa's Talking): " AT_KEY
read -p "Enter AT_USERNAME (Africa's Talking): " AT_USER
read -p "Enter MPESA_CONSUMER_KEY (Safaricom): " MPESA_KEY
read -sp "Enter MPESA_CONSUMER_SECRET (Safaricom): " MPESA_SECRET
echo
read -sp "Enter MPESA_PASSKEY (Safaricom): " MPESA_PASS
echo

kubectl create secret generic app-secrets \
  --from-literal=JWT_SECRET="$JWT_SECRET" \
  --from-literal=AT_API_KEY="$AT_KEY" \
  --from-literal=AT_USERNAME="$AT_USER" \
  --from-literal=MPESA_CONSUMER_KEY="$MPESA_KEY" \
  --from-literal=MPESA_CONSUMER_SECRET="$MPESA_SECRET" \
  --from-literal=MPESA_PASSKEY="$MPESA_PASS" \
  -n $NAMESPACE \
  --dry-run=client -o yaml | kubectl apply -f -

echo "⚙️  Creating ConfigMap..."
kubectl create configmap app-config \
  --from-literal=NODE_ENV=production \
  --from-literal=NEXT_PUBLIC_APP_URL=https://baraza.ke \
  --from-literal=NEXT_PUBLIC_API_URL=https://api.baraza.ke \
  --from-literal=LOG_LEVEL=info \
  --from-literal=OBS_REGION="$OBS_REGION" \
  --from-literal=OBS_BUCKET="$OBS_BUCKET" \
  --from-literal=MPESA_BASE_URL=https://api.safaricom.co.ke \
  --from-literal=MPESA_SHORTCODE=174379 \
  --from-literal=MPESA_CALLBACK_URL=https://api.baraza.ke/api/mpesa/callback \
  -n $NAMESPACE \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Verifying secrets..."
kubectl get secrets -n $NAMESPACE
echo ""
echo "✨ Secrets setup complete!"
