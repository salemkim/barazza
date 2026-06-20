# Baraza Huawei Cloud Deployment Guide

## Overview

This document provides comprehensive instructions for migrating and deploying the **Baraza Kenya Civic Platform** from Vercel/Supabase to **Huawei Cloud**. The migration involves replacing cloud infrastructure components while maintaining full functional compatibility.

### Project Summary
- **Application Type**: Next.js 14 Full-Stack Web Application (TypeScript)
- **Target Users**: Kenyan voters, political candidates, and administrators
- **Current Infrastructure**: Vercel, Supabase (PostgreSQL + Storage), Africa's Talking SMS, Safaricom M-Pesa
- **New Infrastructure**: Huawei Cloud (CCE/ECS, RDS, OBS, API Gateway)

---

## Table of Contents

1. [Service Mapping](#service-mapping)
2. [Architecture Overview](#architecture-overview)
3. [Prerequisites](#prerequisites)
4. [Step-by-Step Deployment](#step-by-step-deployment)
5. [Code Changes & Adjustments](#code-changes--adjustments)
6. [Security & IAM Configuration](#security--iam-configuration)
7. [Monitoring & Logging](#monitoring--logging)
8. [Validation Checklist](#validation-checklist)
9. [Rollback & Troubleshooting](#rollback--troubleshooting)

---

## Service Mapping

### Old vs Huawei Cloud Equivalents

| Component | Current (Vercel/Supabase) | Huawei Cloud Equivalent | Purpose |
|-----------|--------------------------|------------------------|---------|
| **Hosting** | Vercel | CCE (Kubernetes) or ECS | Application runtime |
| **Database** | Supabase PostgreSQL | RDS for PostgreSQL | Relational data storage |
| **Object Storage** | Supabase Storage | OBS (Object Storage Service) | Profile images, candidate assets |
| **API Gateway** | Vercel Functions | API Gateway | Route handling, rate limiting |
| **CDN** | Vercel CDN | CDN (Huawei Cloud CDN) | Static content & image delivery |
| **Secrets Management** | Vercel Environment Variables | KMS + Secrets Manager | API keys, credentials |
| **CI/CD** | GitHub Actions | CodePipeline | Build & deployment automation |
| **Monitoring** | Vercel Analytics | Cloud Eye + LTS | Application performance monitoring |
| **SMS Gateway** | Africa's Talking | Africa's Talking (unchanged) | OTP & notifications |
| **Payment Processing** | Safaricom M-Pesa | Safaricom M-Pesa (unchanged) | Payment callbacks |

---

## Architecture Overview

### Huawei Cloud Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Internet Users                         │
└────────────────────────────┬────────────────────────────────┘
                             │
                    ┌────────▼────────┐
                    │  API Gateway    │
                    │ (Route + Limit) │
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
   ┌────▼────┐        ┌─────▼──────┐     ┌──────▼────┐
   │  CDN    │        │   Baraza   │     │   OBS     │
   │ (Static)│        │ App (CCE)  │     │ (Storage) │
   └─────────┘        └─────┬──────┘     └───────────┘
                             │
                    ┌────────▼────────┐
                    │  RDS PostgreSQL │
                    │  (Database)     │
                    └─────────────────┘
        
        External Services (unchanged):
        ├─ Africa's Talking SMS API
        ├─ Safaricom M-Pesa Daraja
        └─ Google Fonts & CDN
```

### Data Flow

1. **User Requests** → API Gateway → Next.js App (CCE)
2. **Database Queries** → RDS PostgreSQL
3. **File Uploads** → OBS (Object Storage Service)
4. **Static Assets** → CDN Cache
5. **SMS/OTP** → Africa's Talking API
6. **Payments** → Safaricom M-Pesa (callback to API Gateway)

---

## Prerequisites

### Required Access & Accounts
- Huawei Cloud Account with appropriate IAM permissions
- Huawei Cloud Region: **cn-south-1** (Guangzhou, recommended) or **ap-southeast-1** (Singapore)
- Docker installed locally
- kubectl (Kubernetes CLI) installed
- Git and Node.js 18+ installed
- Africa's Talking account (existing)
- Safaricom M-Pesa Daraja credentials (existing)

### Huawei Cloud Services to Enable
- Cloud Container Engine (CCE)
- Relational Database Service (RDS)
- Object Storage Service (OBS)
- API Gateway
- Cloud Image Repository (SWR)
- VPC & Subnets
- Elastic IP (EIP)
- Key Management Service (KMS)
- Cloud Eye (Monitoring)

---

## Step-by-Step Deployment

### Phase 1: Infrastructure Setup (Huawei Cloud Console)

#### Step 1.1: Create VPC and Subnets
```bash
# In Huawei Cloud Console:
1. Go to VPC → Virtual Private Cloud
2. Create VPC: "baraza-vpc"
   - CIDR: 10.0.0.0/16
3. Create Subnet: "baraza-subnet-1"
   - CIDR: 10.0.1.0/24
   - Gateway: 10.0.1.1
   - DNS: 100.125.0.33
```

#### Step 1.2: Create RDS PostgreSQL Instance
```bash
# In Huawei Cloud Console:
1. Go to RDS → Instances
2. Create Instance:
   - Database: PostgreSQL 14.x
   - Flavor: db.r7.large (2 vCPU, 8 GB RAM - adjustable based on load)
   - Storage: 100 GB SSD (auto-expand enabled)
   - VPC: baraza-vpc
   - Subnet: baraza-subnet-1
   - High Availability: Enabled (Multi-AZ)
   - Backup: Daily automated backups (30-day retention)
   - Database Name: baraza_db
   - Root User: postgres
   - Password: Use strong 16+ char password (store in KMS)

3. Note the RDS endpoint: baraza-db.xxx.rds.huaweicloud.com:5432
```

#### Step 1.3: Create OBS Bucket
```bash
# In Huawei Cloud Console:
1. Go to OBS → Buckets
2. Create Bucket:
   - Name: baraza-uploads-{account-id}
   - Region: ap-southeast-1
   - Storage Class: Standard
   - ACL: Private (important for security)
   - Versioning: Enabled
   - Server-side encryption: Enabled (SSE-KMS)
   - CORS: Configure for baraza domain

3. CORS Configuration (JSON):
{
  "CORSRules": [
    {
      "AllowedMethod": ["GET", "PUT", "POST", "DELETE"],
      "AllowedOrigin": ["https://baraza.ke", "https://*.baraza.ke"],
      "AllowedHeader": ["*"],
      "MaxAgeSeconds": 3600
    }
  ]
}

4. Create IAM User for OBS access
5. Note: Bucket Name & Region for env config
```

#### Step 1.4: Set Up Cloud Container Engine (CCE)
```bash
# In Huawei Cloud Console:
1. Go to CCE → Clusters
2. Create Cluster:
   - Name: baraza-cluster
   - Version: Latest stable (1.28+)
   - Cluster Type: VPC cluster
   - VPC: baraza-vpc
   - Subnet: baraza-subnet-1
   - Container Runtime: containerd
   - Node OS: EulerOS

3. Add Node Pool:
   - Name: baraza-worker-pool
   - Node Flavor: s6.xlarge.2 (4 vCPU, 8 GB RAM)
   - Node Count: 3 (auto-scaling 3-10)
   - Storage: 50 GB system disk
   - Auto-repair & auto-scaling: Enabled

4. Download kubeconfig and verify:
   kubectl cluster-info
```

#### Step 1.5: Create API Gateway
```bash
# In Huawei Cloud Console:
1. Go to API Gateway
2. Create API Group:
   - Name: baraza-apis
   - Description: Baraza civic platform APIs

3. Will configure routes in deployment phase
```

#### Step 1.6: Configure KMS & Secrets
```bash
# In Huawei Cloud Console:
1. Go to KMS (Key Management Service)
2. Create Master Key:
   - Name: baraza-secrets-key
   - Description: For encrypting sensitive data
   - Auto-rotation: Enabled (yearly)

3. Go to Secrets Manager
4. Store secrets:
   - POSTGRES_PASSWORD
   - MPESA_CONSUMER_SECRET
   - AT_API_KEY
   - JWT_SECRET
```

---

### Phase 2: Application Preparation

#### Step 2.1: Clone & Setup Repository
```bash
git clone https://github.com/salemkim/barazza.git
cd barazza
git checkout huawei-cloud-migration

# Install dependencies
npm install

# Verify build
npm run build
```

#### Step 2.2: Update Environment Configuration
Create `.env.huawei` (see Configuration section below)

#### Step 2.3: Build Docker Image
```bash
# Create Dockerfile (provided below)
cat > Dockerfile <<'EOF'
FROM node:18-alpine

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci --only=production

# Build Next.js
COPY . .
RUN npm run build

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/api/health', (r) => {if (r.statusCode !== 200) throw new Error(r.statusCode)})"

# Start application
CMD ["npm", "start"]
EOF

# Build image
docker build -t baraza:latest .
docker tag baraza:latest {account-id}.dkr.{region}.huaweicloud.com/baraza/app:latest
```

#### Step 2.4: Push to Huawei Container Registry
```bash
# Login to registry
docker login -u {username} {account-id}.dkr.{region}.huaweicloud.com

# Push image
docker push {account-id}.dkr.{region}.huaweicloud.com/baraza/app:latest
```

---

### Phase 3: Database Migration

#### Step 3.1: Backup Existing Database
```bash
# From Supabase/current environment
pg_dump -h {current-db-host} -U postgres baraza_db > baraza_backup.sql
```

#### Step 3.2: Restore to Huawei RDS
```bash
# Connect to Huawei RDS
psql -h baraza-db.xxx.rds.huaweicloud.com -U postgres -d baraza_db < baraza_backup.sql

# Verify schema
psql -h baraza-db.xxx.rds.huaweicloud.com -U postgres -d baraza_db -c "\dt"
```

#### Step 3.3: Run Migrations
```bash
# If using Drizzle migrations
DATABASE_URL="postgresql://postgres:password@baraza-db.xxx.rds.huaweicloud.com:5432/baraza_db" \
npm run migrate
```

---

### Phase 4: Kubernetes Deployment

#### Step 4.1: Create Namespace & Secrets
```bash
# Set kubeconfig
export KUBECONFIG=~/kubeconfig.json

# Create namespace
kubectl create namespace baraza-prod

# Create database secret
kubectl create secret generic db-credentials \
  --from-literal=DATABASE_URL="postgresql://postgres:{password}@baraza-db.xxx.rds.huaweicloud.com:5432/baraza_db" \
  -n baraza-prod

# Create OBS credentials secret
kubectl create secret generic obs-credentials \
  --from-literal=OBS_ACCESS_KEY={access-key} \
  --from-literal=OBS_SECRET_KEY={secret-key} \
  --from-literal=OBS_REGION=ap-southeast-1 \
  --from-literal=OBS_BUCKET=baraza-uploads-{account-id} \
  -n baraza-prod

# Create app secrets
kubectl create secret generic app-secrets \
  --from-literal=JWT_SECRET=$(openssl rand -base64 32) \
  --from-literal=AT_API_KEY={at-api-key} \
  --from-literal=AT_USERNAME={at-username} \
  --from-literal=MPESA_CONSUMER_KEY={mpesa-key} \
  --from-literal=MPESA_CONSUMER_SECRET={mpesa-secret} \
  --from-literal=MPESA_PASSKEY={mpesa-passkey} \
  -n baraza-prod
```

#### Step 4.2: Create ConfigMap for Non-Sensitive Config
```bash
kubectl create configmap app-config \
  --from-literal=NEXT_PUBLIC_APP_URL=https://baraza.ke \
  --from-literal=NEXT_PUBLIC_API_URL=https://api.baraza.ke \
  --from-literal=NODE_ENV=production \
  --from-literal=LOG_LEVEL=info \
  --from-literal=OBS_REGION=ap-southeast-1 \
  --from-literal=OBS_BUCKET=baraza-uploads-{account-id} \
  --from-literal=MPESA_BASE_URL=https://api.safaricom.co.ke \
  --from-literal=MPESA_SHORTCODE=174379 \
  --from-literal=MPESA_CALLBACK_URL=https://api.baraza.ke/api/mpesa/callback \
  -n baraza-prod
```

#### Step 4.3: Deploy Application
Create `k8s/deployment.yaml` (see file in deployment section)

```bash
kubectl apply -f k8s/deployment.yaml -n baraza-prod
kubectl apply -f k8s/service.yaml -n baraza-prod
kubectl apply -f k8s/ingress.yaml -n baraza-prod

# Verify deployment
kubectl get deployments -n baraza-prod
kubectl get pods -n baraza-prod
kubectl logs -f deployment/baraza-app -n baraza-prod
```

#### Step 4.4: Scale & Auto-scaling
```bash
# Set up HPA (Horizontal Pod Autoscaler)
kubectl apply -f k8s/hpa.yaml -n baraza-prod

# Verify HPA
kubectl get hpa -n baraza-prod
```

---

### Phase 5: Networking & Domain Configuration

#### Step 5.1: Configure API Gateway
```bash
# In Huawei Cloud Console → API Gateway
1. Create API:
   - Method: ANY
   - Path: /api/*
   - Type: HTTP
   - Endpoint: baraza-app-service.baraza-prod.svc.cluster.local:3000

2. Configure Request/Response Transformations
3. Set Rate Limiting:
   - 1000 requests per minute per user
   - 50,000 requests per minute globally

4. Enable Logging & Monitoring
```

#### Step 5.2: Setup Elastic IP & DNS
```bash
# Allocate EIP
huaweicloud vpc eip create --bandwidth 10

# Configure DNS
1. Go to DNS Console
2. Create Zone: baraza.ke
3. Add Records:
   - A record: api.baraza.ke → {eip}
   - A record: baraza.ke → {eip}
   - MX record: (if needed for emails)
   - TXT record: (for SPF/verification)
```

#### Step 5.3: SSL/TLS Certificate
```bash
# Request certificate via Cloud Certificate Manager
1. Go to Certificate Management
2. Request Certificate:
   - Domain: *.baraza.ke, baraza.ke
   - Validation: DNS or Email
   - Auto-renewal: Enabled

3. Configure on API Gateway & Load Balancer
```

---

### Phase 6: Monitoring & Logging Setup

#### Step 6.1: Enable Cloud Eye Monitoring
```bash
# In Huawei Cloud Console
1. Go to Cloud Eye
2. Create Dashboard: "Baraza-Overview"
3. Add Metrics:
   - CPU utilization (CCE)
   - Memory usage (CCE)
   - Database connections
   - Network in/out
   - API latency
   - Error rate

4. Create Alarms:
   - CPU > 70% → Alert
   - Memory > 80% → Alert
   - DB connections > 80 → Alert
   - Error rate > 1% → Alert
```

#### Step 6.2: Configure Log Aggregation
```bash
# Enable LTS (Log Tank Service)
kubectl apply -f k8s/logging.yaml

# Access logs
huaweicloud lts get-logs --stream baraza-app
```

#### Step 6.3: Application Performance Monitoring
```bash
# Install APM agent (optional but recommended)
npm install @huaweicloud/apm-js-agent

# Configure in app
// src/lib/apm.ts
import { APMClient } from '@huaweicloud/apm-js-agent'

const apmClient = new APMClient({
  serviceName: 'baraza-app',
  serverUrl: 'https://apm.huaweicloud.com'
})

export default apmClient
```

---

## Code Changes & Adjustments

### Critical Files Modified

#### 1. Storage Adapter: `src/lib/storage/obs-storage.ts` (NEW)

Replace Supabase storage with OBS implementation:

```typescript
import { GetObjectCommand, PutObjectCommand, DeleteObjectCommand, S3Client } from "@aws-sdk/client-s3"
import { getSignedUrl } from "@aws-sdk/s3-request-presigner"

const obsClient = new S3Client({
  region: process.env.OBS_REGION!,
  credentials: {
    accessKeyId: process.env.OBS_ACCESS_KEY!,
    secretAccessKey: process.env.OBS_SECRET_KEY!,
  },
  endpoint: `https://obs.${process.env.OBS_REGION}.huaweicloud.com`,
})

const BUCKET = process.env.OBS_BUCKET!

export async function uploadFormFile(file: File, folder: string): Promise<string> {
  try {
    const fileName = `${folder}/${Date.now()}-${file.name.replace(/\s+/g, '-')}`
    const buffer = Buffer.from(await file.arrayBuffer())

    const command = new PutObjectCommand({
      Bucket: BUCKET,
      Key: fileName,
      Body: buffer,
      ContentType: file.type,
      Metadata: {
        'upload-time': new Date().toISOString(),
      },
    })

    await obsClient.send(command)
    return `https://${BUCKET}.obs.${process.env.OBS_REGION}.huaweicloud.com/${fileName}`
  } catch (error) {
    console.error('[OBS Upload Error]', error)
    throw new Error('Failed to upload file')
  }
}

export async function deleteFile(fileUrl: string): Promise<void> {
  try {
    const key = fileUrl.split(`${BUCKET}/`)[1]
    if (!key) return

    const command = new DeleteObjectCommand({
      Bucket: BUCKET,
      Key: key,
    })

    await obsClient.send(command)
  } catch (error) {
    console.error('[OBS Delete Error]', error)
  }
}

export async function getSignedUploadUrl(fileName: string, contentType: string): Promise<string> {
  try {
    const key = `uploads/${Date.now()}-${fileName}`
    const command = new PutObjectCommand({
      Bucket: BUCKET,
      Key: key,
      ContentType: contentType,
    })

    return await getSignedUrl(obsClient, command, { expiresIn: 3600 })
  } catch (error) {
    console.error('[OBS Signed URL Error]', error)
    throw new Error('Failed to generate signed URL')
  }
}
```

#### 2. Database Configuration: `src/lib/db/index.ts` (UPDATED)

```typescript
import { drizzle } from 'drizzle-orm/postgres-js'
import postgres from 'postgres'

// Huawei RDS Configuration
const connectionUrl = process.env.DATABASE_URL!

if (!connectionUrl) {
  throw new Error('DATABASE_URL environment variable is not set')
}

// Connection pooling for better performance
const queryClient = postgres(connectionUrl, {
  max: 20, // Connection pool size
  idleTimeout: 30000,
  query_timeout: 30000,
  types: {
    bigint: postgres.BigInt,
  },
})

export const db = drizzle(queryClient, {
  logger: process.env.NODE_ENV === 'development',
})

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, closing database connections...')
  await queryClient.end()
  process.exit(0)
})
```

#### 3. Environment Configuration: `.env.huawei` (NEW)

```env
# Application
NODE_ENV=production
NEXT_PUBLIC_APP_URL=https://baraza.ke
NEXT_PUBLIC_API_URL=https://api.baraza.ke

# Huawei Cloud - Database
DATABASE_URL=postgresql://postgres:{password}@baraza-db.xxx.rds.huaweicloud.com:5432/baraza_db

# Huawei Cloud - OBS Storage
OBS_REGION=ap-southeast-1
OBS_BUCKET=baraza-uploads-{account-id}
OBS_ACCESS_KEY={from-iam-user}
OBS_SECRET_KEY={from-iam-user}

# OBS Endpoint Configuration (auto-derived)
# https://obs.ap-southeast-1.huaweicloud.com

# Authentication
JWT_SECRET={32-char-random-base64}
SESSION_COOKIE_NAME=baraza_session
SESSION_COOKIE_SECURE=true
SESSION_COOKIE_HTTP_ONLY=true
SESSION_COOKIE_SAME_SITE=Lax
SESSION_COOKIE_MAX_AGE=604800

# External APIs - Africa's Talking (SMS)
AT_API_KEY={api-key}
AT_USERNAME={username}
AT_SENDER_ID=BARAZA

# External APIs - Safaricom M-Pesa
MPESA_BASE_URL=https://api.safaricom.co.ke
MPESA_CONSUMER_KEY={consumer-key}
MPESA_CONSUMER_SECRET={consumer-secret}
MPESA_SHORTCODE=174379
MPESA_PASSKEY={lipa-na-mpesa-online-passkey}
MPESA_CALLBACK_URL=https://api.baraza.ke/api/mpesa/callback

# Monitoring & Logging
LOG_LEVEL=info
ENABLE_CLOUD_EYE=true

# Optional: APM
APM_ENABLED=true
APM_SERVICE_NAME=baraza-app
APM_SERVER_URL=https://apm.huaweicloud.com

# Huawei Cloud Region
HUAWEI_REGION=ap-southeast-1
```

#### 4. Remove Supabase: `src/lib/auth/supabase.ts` (DEPRECATED)

Delete this file. Replace all references with direct PostgreSQL connections via Drizzle ORM (already implemented in auth/session.ts).

#### 5. Update Storage Import: `src/lib/storage/index.ts` (NEW)

```typescript
// Re-export from OBS storage instead of Supabase
export { uploadFormFile, deleteFile, getSignedUploadUrl } from './obs-storage'
```

#### 6. Next.js Configuration: `next.config.ts` (UPDATED)

```typescript
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  images: {
    remotePatterns: [
      // Huawei OBS
      {
        protocol: 'https',
        hostname: 'baraza-uploads-*.obs.ap-southeast-1.huaweicloud.com',
      },
      // CDN
      {
        protocol: 'https',
        hostname: 'cdn.baraza.ke',
      },
      // Google Fonts (keep existing)
      {
        protocol: 'https',
        hostname: 'fonts.googleapis.com',
      },
    ],
  },
  headers: async () => [
    {
      source: '/api/:path*',
      headers: [
        {
          key: 'Cache-Control',
          value: 'no-store, must-revalidate',
        },
      ],
    },
  ],
  compress: true,
  productionBrowserSourceMaps: false,
  poweredByHeader: false,
  reactStrictMode: true,
}

export default nextConfig
```

#### 7. Kubernetes Deployment: `k8s/deployment.yaml` (NEW)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: baraza-app
  namespace: baraza-prod
  labels:
    app: baraza
    version: v1
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: baraza
  template:
    metadata:
      labels:
        app: baraza
        version: v1
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchExpressions:
                    - key: app
                      operator: In
                      values:
                        - baraza
                topologyKey: kubernetes.io/hostname
      containers:
        - name: baraza
          image: {account-id}.dkr.ap-southeast-1.huaweicloud.com/baraza/app:latest
          imagePullPolicy: Always
          ports:
            - name: http
              containerPort: 3000
              protocol: TCP
          env:
            - name: NODE_ENV
              valueFrom:
                configMapKeyRef:
                  name: app-config
                  key: NODE_ENV
            - name: NEXT_PUBLIC_APP_URL
              valueFrom:
                configMapKeyRef:
                  name: app-config
                  key: NEXT_PUBLIC_APP_URL
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: db-credentials
                  key: DATABASE_URL
            - name: OBS_REGION
              valueFrom:
                configMapKeyRef:
                  name: app-config
                  key: OBS_REGION
            - name: OBS_BUCKET
              valueFrom:
                configMapKeyRef:
                  name: app-config
                  key: OBS_BUCKET
            - name: OBS_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: obs-credentials
                  key: OBS_ACCESS_KEY
            - name: OBS_SECRET_KEY
              valueFrom:
                secretKeyRef:
                  name: obs-credentials
                  key: OBS_SECRET_KEY
            - name: JWT_SECRET
              valueFrom:
                secretKeyRef:
                  name: app-secrets
                  key: JWT_SECRET
            - name: AT_API_KEY
              valueFrom:
                secretKeyRef:
                  name: app-secrets
                  key: AT_API_KEY
            - name: AT_USERNAME
              valueFrom:
                secretKeyRef:
                  name: app-secrets
                  key: AT_USERNAME
            - name: MPESA_CONSUMER_KEY
              valueFrom:
                secretKeyRef:
                  name: app-secrets
                  key: MPESA_CONSUMER_KEY
            - name: MPESA_CONSUMER_SECRET
              valueFrom:
                secretKeyRef:
                  name: app-secrets
                  key: MPESA_CONSUMER_SECRET
            - name: MPESA_PASSKEY
              valueFrom:
                secretKeyRef:
                  name: app-secrets
                  key: MPESA_PASSKEY
          resources:
            requests:
              memory: "512Mi"
              cpu: "250m"
            limits:
              memory: "1Gi"
              cpu: "500m"
          livenessProbe:
            httpGet:
              path: /api/health
              port: http
            initialDelaySeconds: 30
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /api/health
              port: http
            initialDelaySeconds: 10
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 2
          lifecycle:
            preStop:
              exec:
                command: ["/bin/sh", "-c", "sleep 15"]
      imagePullSecrets:
        - name: swr-auth
      terminationGracePeriodSeconds: 30
```

#### 8. Kubernetes Service: `k8s/service.yaml` (NEW)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: baraza-app-service
  namespace: baraza-prod
  labels:
    app: baraza
spec:
  type: ClusterIP
  ports:
    - port: 3000
      targetPort: 3000
      protocol: TCP
      name: http
  selector:
    app: baraza
```

#### 9. Kubernetes Ingress: `k8s/ingress.yaml` (NEW)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: baraza-ingress
  namespace: baraza-prod
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/rate-limit: "100"
spec:
  tls:
    - hosts:
        - baraza.ke
        - api.baraza.ke
      secretName: baraza-tls
  rules:
    - host: baraza.ke
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: baraza-app-service
                port:
                  number: 3000
    - host: api.baraza.ke
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: baraza-app-service
                port:
                  number: 3000
```

#### 10. HPA Configuration: `k8s/hpa.yaml` (NEW)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: baraza-hpa
  namespace: baraza-prod
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: baraza-app
  minReplicas: 3
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 50
          periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
        - type: Percent
          value: 100
          periodSeconds: 30
        - type: Pods
          value: 2
          periodSeconds: 30
      selectPolicy: Max
```

#### 11. API Health Check: `src/app/api/health/route.ts` (NEW)

```typescript
import { db } from '@/lib/db'
import { NextResponse } from 'next/server'

export async function GET() {
  try {
    // Check database connectivity
    await db.execute('SELECT 1')
    
    return NextResponse.json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      version: process.env.npm_package_version,
      environment: process.env.NODE_ENV,
    })
  } catch (error) {
    console.error('[Health Check Failed]', error)
    return NextResponse.json(
      {
        status: 'unhealthy',
        error: error instanceof Error ? error.message : 'Unknown error',
        timestamp: new Date().toISOString(),
      },
      { status: 503 }
    )
  }
}
```

#### 12. Updated Dockerfile

```dockerfile
FROM node:18-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM node:18-alpine

WORKDIR /app

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1

ENTRYPOINT ["dumb-init", "--"]
CMD ["npm", "start"]
```

---

## Security & IAM Configuration

### 1. Huawei IAM Roles & Policies

#### Create Custom Role for Application
```json
{
  "Version": "1.1",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "rds:GetDatabase",
        "rds:DescribeInstances"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "obs:GetObject",
        "obs:PutObject",
        "obs:DeleteObject",
        "obs:ListBucket"
      ],
      "Resource": [
        "arn:huawei:obs::*:baraza-uploads-*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:CreateGrant",
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ],
      "Resource": "arn:huawei:kms:*:*:key/*"
    }
  ]
}
```

### 2. Network Security

#### Security Group Configuration
```bash
# Inbound Rules
- HTTP (80): 0.0.0.0/0 (redirect to HTTPS)
- HTTPS (443): 0.0.0.0/0 (only allowed)
- SSH (22): Admin IP only (for debugging)

# Outbound Rules
- All traffic allowed (needed for external APIs)
```

#### Database Security
```bash
# RDS Security Group
- PostgreSQL (5432): CCE subnet only (10.0.1.0/24)
- Deny all other inbound
```

### 3. Data Encryption

#### Transit Encryption
- All API traffic: HTTPS/TLS 1.2+
- Database: Encrypted connections (sslmode=require)
- OBS: HTTPS only

#### At-Rest Encryption
- RDS: AWS KMS encryption
- OBS: Server-side encryption (SSE-KMS)
- Secrets: Huawei KMS encryption

### 4. Credential Management

```bash
# Never commit secrets
echo ".env.local" >> .gitignore
echo ".env.production" >> .gitignore

# Rotate credentials quarterly
# Instructions: Huawei Console → IAM → Users → {user} → Manage Access Keys

# For emergency rotation:
kubectl patch secret app-secrets \
  -p '{"data":{"JWT_SECRET":"'$(echo -n $(openssl rand -base64 32) | base64 -w0)'"}}'
kubectl rollout restart deployment/baraza-app -n baraza-prod
```

---

## Monitoring & Logging

### 1. Application Metrics (Cloud Eye)

```bash
# Create dashboard queries
- CPU: cpu_util{namespace='baraza-prod', pod_name='baraza-app-*'}
- Memory: mem_util{namespace='baraza-prod'}
- Network: network_transmit_bytes{namespace='baraza-prod'}
- API Latency: histogram_quantile(0.95, http_request_duration_ms)
- Error Rate: rate(http_requests_total{status=~'5..'}[5m])
```

### 2. Application Logging

```typescript
// src/lib/logger.ts
import pino from 'pino'

const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  transport: {
    target: 'pino-loki',
    options: {
      host: process.env.LOKI_HOST || 'localhost',
      labels: {
        job: 'baraza-app',
        env: process.env.NODE_ENV,
      },
    },
  },
})

export default logger
```

### 3. Error Tracking

```typescript
// src/lib/sentry.ts (optional: upgrade to Sentry)
import * as Sentry from "@sentry/nextjs";

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
  tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 1.0,
});

export default Sentry;
```

### 4. Request Tracing

```typescript
// src/middleware.ts - add X-Request-ID
import { NextRequest, NextResponse } from 'next/server'
import { v4 as uuidv4 } from 'uuid'

export function middleware(request: NextRequest) {
  const requestId = request.headers.get('x-request-id') || uuidv4()
  const response = NextResponse.next()
  response.headers.set('x-request-id', requestId)
  return response
}
```

---

## Validation Checklist

### Pre-Deployment Validation
- [ ] All environment variables are set correctly
- [ ] Database backup created and tested
- [ ] Docker image builds without errors
- [ ] Docker image runs locally with correct env
- [ ] All tests pass: `npm run test`
- [ ] No hardcoded credentials in code
- [ ] `.env` files added to `.gitignore`

### Post-Deployment Validation
- [ ] Pods are running: `kubectl get pods -n baraza-prod`
- [ ] Health check passes: `curl https://api.baraza.ke/api/health`
- [ ] Database connectivity confirmed
- [ ] OBS storage working: test file upload
- [ ] SMS sending works: test OTP
- [ ] M-Pesa callback receiving: test payment
- [ ] SSL/TLS certificate valid: `openssl s_client -connect api.baraza.ke:443`
- [ ] DNS resolution working
- [ ] Admin panel accessible
- [ ] User registration flow complete
- [ ] Candidate registration with file upload works
- [ ] Feed pagination works
- [ ] Direct messaging works
- [ ] Moderation dashboard functional
- [ ] Payment processing works end-to-end
- [ ] Monitor Cloud Eye dashboards for anomalies

### Performance Validation
- [ ] API latency p95 < 500ms
- [ ] Homepage load time < 2s
- [ ] Database query response < 100ms
- [ ] OBS upload/download < 1s for 5MB files
- [ ] Concurrent users handled correctly (load test)
- [ ] Memory usage stable (no leaks)
- [ ] CPU usage within expected range
- [ ] Error rate < 0.5%

### Security Validation
- [ ] All traffic over HTTPS
- [ ] No secrets in logs
- [ ] WAF rules active on API Gateway
- [ ] Rate limiting enforced
- [ ] CORS properly configured
- [ ] Database accessible only from app
- [ ] OBS bucket not publicly readable
- [ ] Security headers present (CSP, X-Frame-Options)
- [ ] SQL injection prevention verified
- [ ] XSS protection enabled

---

## Rollback & Troubleshooting

### Rollback to Previous Version

```bash
# View deployment history
kubectl rollout history deployment/baraza-app -n baraza-prod

# Rollback to previous version
kubectl rollout undo deployment/baraza-app -n baraza-prod

# Rollback to specific revision
kubectl rollout undo deployment/baraza-app --to-revision=2 -n baraza-prod

# Verify rollback
kubectl get pods -n baraza-prod
kubectl logs deployment/baraza-app -n baraza-prod
```

### Common Issues & Solutions

#### Issue: Database Connection Timeout
```bash
# Check RDS instance status
huaweicloud rds list-instances

# Verify security group
huaweicloud vpc sg describe-rules

# Test connection
psql -h baraza-db.xxx.rds.huaweicloud.com -U postgres -d baraza_db -c "SELECT 1"

# Solution: Ensure pod CIDR (10.0.1.0/24) is allowed in RDS security group
```

#### Issue: OBS Upload Fails with 403
```bash
# Check OBS credentials
kubectl get secret obs-credentials -o yaml -n baraza-prod

# Verify IAM user has OBS permissions
huaweicloud iam list-user-policies --user {user-id}

# Test OBS access
aws s3 ls s3://baraza-uploads-{account-id}/ --endpoint-url https://obs.ap-southeast-1.huaweicloud.com
```

#### Issue: High Memory Usage
```bash
# Check memory usage
kubectl top pods -n baraza-prod

# View heap dump
kubectl exec -it pod/baraza-app-xxx -n baraza-prod -- node --inspect=0.0.0.0:9229

# Reduce memory limit or increase pod resources
kubectl set resources deployment baraza-app --limits=memory=2Gi -n baraza-prod
```

#### Issue: Pods Not Starting
```bash
# Check pod logs
kubectl logs pod/baraza-app-xxx -n baraza-prod

# Describe pod for events
kubectl describe pod baraza-app-xxx -n baraza-prod

# Check resource availability
kubectl top nodes
```

#### Issue: M-Pesa Callback Not Received
```bash
# Verify callback URL is correct
echo $MPESA_CALLBACK_URL

# Check API Gateway logs
huaweicloud apigw list-logs

# Test endpoint manually
curl -X POST https://api.baraza.ke/api/mpesa/callback \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'

# Solution: Ensure API Gateway routes /api/mpesa/* correctly
```

### Debug Commands

```bash
# SSH into pod
kubectl exec -it pod/baraza-app-xxx -n baraza-prod -- /bin/sh

# Stream logs in real-time
kubectl logs -f deployment/baraza-app -n baraza-prod

# Check events
kubectl get events -n baraza-prod --sort-by='.lastTimestamp'

# Describe node
kubectl describe node {node-name}

# Check HPA status
kubectl describe hpa baraza-hpa -n baraza-prod

# Test DNS
kubectl run -it --rm debug --image=alpine --restart=Never -- nslookup baraza-app-service.baraza-prod.svc.cluster.local
```

---

## Appendix: Scripts

### Automated Deployment Script

```bash
#!/bin/bash
# deploy.sh - Automated Huawei Cloud deployment

set -e

ENV=${1:-production}
IMAGE_TAG=${2:-latest}
REGION=ap-southeast-1
ACCOUNT_ID=${3:-YOUR_ACCOUNT_ID}

echo "🚀 Starting deployment for environment: $ENV"

# 1. Build and push Docker image
echo "📦 Building Docker image..."
docker build -t baraza:${IMAGE_TAG} .
docker tag baraza:${IMAGE_TAG} ${ACCOUNT_ID}.dkr.${REGION}.huaweicloud.com/baraza/app:${IMAGE_TAG}

echo "🔐 Logging in to registry..."
docker login -u ${REGISTRY_USER} ${ACCOUNT_ID}.dkr.${REGION}.huaweicloud.com

echo "📤 Pushing image..."
docker push ${ACCOUNT_ID}.dkr.${REGION}.huaweicloud.com/baraza/app:${IMAGE_TAG}

# 2. Update kubeconfig
echo "🔧 Configuring kubectl..."
export KUBECONFIG=~/kubeconfig.json

# 3. Deploy to Kubernetes
echo "☸️  Deploying to CCE..."
kubectl set image deployment/baraza-app \
  baraza=${ACCOUNT_ID}.dkr.${REGION}.huaweicloud.com/baraza/app:${IMAGE_TAG} \
  -n baraza-prod

# 4. Wait for rollout
echo "⏳ Waiting for rollout..."
kubectl rollout status deployment/baraza-app -n baraza-prod --timeout=5m

# 5. Verify deployment
echo "✅ Verifying deployment..."
kubectl get pods -n baraza-prod
kubectl get svc -n baraza-prod

# 6. Run smoke tests
echo "🧪 Running smoke tests..."
curl -f https://api.baraza.ke/api/health || exit 1

echo "✨ Deployment complete!"
```

### Database Migration Script

```bash
#!/bin/bash
# migrate-db.sh - Migrate database from Supabase to Huawei RDS

set -e

OLD_HOST=${1:-old-db.supabase.co}
OLD_USER=${2:-postgres}
OLD_PASSWORD=${3}
NEW_HOST=${4:-baraza-db.xxx.rds.huaweicloud.com}
NEW_USER=${5:-postgres}
NEW_PASSWORD=${6}

echo "📊 Starting database migration..."

# 1. Backup old database
echo "💾 Creating backup from source..."
PGPASSWORD=${OLD_PASSWORD} pg_dump -h ${OLD_HOST} -U ${OLD_USER} baraza_db > baraza_backup.sql

# 2. Restore to new database
echo "📥 Restoring to Huawei RDS..."
PGPASSWORD=${NEW_PASSWORD} psql -h ${NEW_HOST} -U ${NEW_USER} -d baraza_db < baraza_backup.sql

# 3. Verify migration
echo "✅ Verifying migration..."
PGPASSWORD=${NEW_PASSWORD} psql -h ${NEW_HOST} -U ${NEW_USER} -d baraza_db \
  -c "SELECT COUNT(*) as table_count FROM information_schema.tables WHERE table_schema = 'public';"

echo "✨ Migration complete!"
```

---

## Conclusion

This guide provides a complete migration path from Vercel/Supabase to Huawei Cloud while maintaining full application functionality. Key migration benefits:

- **Cost Optimization**: Potential 30-50% cost reduction
- **Regional Compliance**: Data residency in Asia-Pacific
- **Performance**: Lower latency for Kenya-based users
- **Scalability**: Unlimited horizontal scaling with Kubernetes
- **Control**: Full infrastructure control and customization

For support, refer to:
- [Huawei Cloud Documentation](https://support.huaweicloud.com)
- [Huawei Cloud API Reference](https://support.huaweicloud.com/api/obs.html)
- [Kubernetes Official Docs](https://kubernetes.io/docs/)

---

**Last Updated**: 2026-06-20  
**Version**: 1.0  
**Status**: Production Ready
