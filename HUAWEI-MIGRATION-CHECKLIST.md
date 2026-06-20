# Baraza Huawei Cloud Migration Checklist

## Pre-Migration Checklist

### Access & Permissions
- [ ] Huawei Cloud account created and active
- [ ] IAM user created with necessary permissions
- [ ] Account ID obtained
- [ ] Region selected (ap-southeast-1 recommended)

### Prerequisites
- [ ] Docker installed locally
- [ ] kubectl installed and configured
- [ ] Git installed
- [ ] Node.js 18+ installed
- [ ] Africa's Talking account active
- [ ] Safaricom M-Pesa Daraja credentials ready

## Infrastructure Setup

### VPC & Networking
- [ ] VPC created (baraza-vpc, CIDR: 10.0.0.0/16)
- [ ] Subnet created (baraza-subnet-1, CIDR: 10.0.1.0/24)
- [ ] Security groups configured
- [ ] NAT Gateway configured (if needed)
- [ ] Route tables configured

### Database
- [ ] RDS PostgreSQL instance created
- [ ] Instance flavor: db.r7.large or equivalent
- [ ] Storage: 100GB SSD with auto-expand
- [ ] Multi-AZ enabled
- [ ] Automated backups configured (30-day retention)
- [ ] Database name: baraza_db
- [ ] Master user: postgres
- [ ] Database endpoint noted
- [ ] Security group allows access from CCE subnet
- [ ] Database backup created and tested

### Object Storage
- [ ] OBS bucket created (baraza-uploads-{account-id})
- [ ] Bucket region set to ap-southeast-1
- [ ] Versioning enabled
- [ ] Server-side encryption enabled (SSE-KMS)
- [ ] CORS configuration applied
- [ ] IAM user created for OBS access
- [ ] Access key and secret key obtained
- [ ] Bucket is private (ACL)

### Container Engine
- [ ] CCE cluster created
- [ ] Cluster version: 1.28+
- [ ] VPC: baraza-vpc
- [ ] Subnet: baraza-subnet-1
- [ ] Node pool created with 3 nodes
- [ ] Node flavor: s6.xlarge.2 or equivalent
- [ ] Auto-scaling configured (3-10 nodes)
- [ ] kubeconfig downloaded and configured
- [ ] kubectl can communicate with cluster

### Registry
- [ ] SWR (Software Repository for Containers) enabled
- [ ] Registry organization created
- [ ] Docker login credentials obtained

### Security & Encryption
- [ ] KMS master key created (baraza-secrets-key)
- [ ] Secrets Manager configured
- [ ] SSL/TLS certificates obtained
- [ ] WAF rules configured (optional)

## Code Preparation

### Repository Setup
- [ ] Repository cloned locally
- [ ] Branch checked out: huawei-cloud-migration
- [ ] Dependencies installed (npm install)
- [ ] Build verified (npm run build)
- [ ] Tests passing (npm run test)

### Code Updates
- [ ] OBS storage adapter implemented
- [ ] Database configuration updated
- [ ] Supabase references removed
- [ ] Environment variables updated
- [ ] Health check endpoint created
- [ ] No hardcoded secrets in code
- [ ] .env files added to .gitignore

### Docker Build
- [ ] Dockerfile created and tested locally
- [ ] Build succeeds without errors
- [ ] Image size optimized
- [ ] Health check working

## Database Migration

- [ ] Current database backed up
- [ ] Backup tested for integrity
- [ ] Backup restored to Huawei RDS
- [ ] Schema verified
- [ ] Data integrity verified
- [ ] Migrations run successfully
- [ ] Indexes created
- [ ] Query performance tested

## Container Registry

- [ ] Docker image built
- [ ] Image tagged correctly
- [ ] Docker logged into Huawei registry
- [ ] Image pushed to registry
- [ ] Image accessible from CCE

## Kubernetes Deployment

### Namespace & Secrets
- [ ] baraza-prod namespace created
- [ ] Database credentials secret created
- [ ] OBS credentials secret created
- [ ] Application secrets created
- [ ] ConfigMap created
- [ ] Docker registry secret created (swr-auth)

### Deployment
- [ ] Deployment YAML created
- [ ] Deployment applied (kubectl apply)
- [ ] Pods starting successfully
- [ ] Service created and accessible
- [ ] Replica count correct (3)
- [ ] Resource requests/limits set
- [ ] Health checks configured

### Auto-Scaling
- [ ] HPA created
- [ ] Min replicas: 3
- [ ] Max replicas: 10
- [ ] CPU threshold: 70%
- [ ] Memory threshold: 80%

## Networking & DNS

### API Gateway
- [ ] API Gateway configured
- [ ] Routes created
- [ ] Rate limiting enabled
- [ ] CORS configured
- [ ] SSL/TLS certificate installed

### DNS
- [ ] Domain baraza.ke configured
- [ ] api.baraza.ke configured
- [ ] A records pointing to EIP
- [ ] DNS propagation verified
- [ ] SSL certificate valid
- [ ] HTTPS enforced

### Load Balancing
- [ ] Elastic IP allocated
- [ ] Load balancer configured
- [ ] Health checks working
- [ ] Traffic routing verified

## Monitoring & Logging

### Cloud Eye
- [ ] Dashboard created
- [ ] CPU metric added
- [ ] Memory metric added
- [ ] Network metrics added
- [ ] API latency metric added
- [ ] Error rate metric added
- [ ] Alarms configured
- [ ] Email notifications enabled

### Log Aggregation
- [ ] LTS enabled
- [ ] Application logs flowing
- [ ] Log queries working
- [ ] Retention policy set

### APM (Optional)
- [ ] APM agent installed
- [ ] Transaction tracing enabled
- [ ] Error tracking working

## Testing & Validation

### Functional Tests
- [ ] API health check: GET /api/health → 200
- [ ] Database query: SELECT 1 → success
- [ ] OBS upload: Test file → success
- [ ] OBS download: Test file → success
- [ ] SMS sending: OTP test → delivered
- [ ] M-Pesa callback: Test payment → received
- [ ] User registration: Complete flow → success
- [ ] Candidate registration: With upload → success
- [ ] Feed loading: Multiple pages → success
- [ ] Direct messaging: Send/receive → success
- [ ] Moderation: Report content → success
- [ ] Payment: End-to-end → success

### Performance Tests
- [ ] API latency p95 < 500ms
- [ ] Homepage load < 2s
- [ ] Database query < 100ms
- [ ] OBS upload/download < 1s (5MB)
- [ ] Memory usage stable
- [ ] CPU usage within limits
- [ ] No memory leaks (24h test)
- [ ] Concurrent users handled (load test)

### Security Tests
- [ ] HTTPS enforced
- [ ] No secrets in logs
- [ ] SQL injection protection verified
- [ ] XSS protection verified
- [ ] CORS properly configured
- [ ] Rate limiting working
- [ ] WAF rules active
- [ ] Database accessible only internally
- [ ] OBS bucket not publicly readable
- [ ] Security headers present

## Post-Deployment

- [ ] All pods running
- [ ] All services accessible
- [ ] Monitoring dashboards populated
- [ ] Logs flowing correctly
- [ ] Alerts configured and tested
- [ ] Backup schedule configured
- [ ] Disaster recovery plan documented
- [ ] Team trained on operations
- [ ] Documentation completed
- [ ] Runbooks created

## Rollback Plan

- [ ] Previous version image available
- [ ] Database backup available
- [ ] Rollback procedure documented
- [ ] Team familiar with rollback steps
- [ ] DNS failover plan ready

## Sign-Off

- [ ] QA sign-off: _____________ Date: _______
- [ ] Ops sign-off: ____________ Date: _______
- [ ] DevOps sign-off: __________ Date: _______
- [ ] Product sign-off: _________ Date: _______

---

## Notes

```



```
