# Deployment Guide - Concrete Sales & Profit Analyzer

## Infrastructure Overview

### Production Architecture
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Load Balancer │    │       CDN       │    │  File Storage   │
│   (ALB/NGINX)   │    │   (CloudFront)  │    │      (S3)       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │  API Gateway    │
                    │   (Kong/AWS)    │
                    └─────────────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                       │                       │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Frontend App   │    │  Backend API    │    │   Analytics     │
│  (React/Nginx)  │    │   (Node.js)     │    │   Service       │
│  Auto-scaling   │    │  Auto-scaling   │    │  (Python/ML)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   Database      │
                    │  (PostgreSQL)   │
                    │  with Read      │
                    │   Replicas      │
                    └─────────────────┘
                                 │
                    ┌─────────────────┐
                    │     Cache       │
                    │    (Redis)      │
                    │   Cluster       │
                    └─────────────────┘
```

### Environment Strategy
- **Development**: Local development with Docker Compose
- **Staging**: Production-like environment for testing
- **Production**: High-availability multi-AZ deployment
- **Disaster Recovery**: Cross-region backup environment

## Cloud Provider Recommendations

### AWS Deployment (Recommended)

#### Core Services
```yaml
compute:
  frontend: "AWS ECS Fargate (React app)"
  backend: "AWS ECS Fargate (Node.js API)"  
  analytics: "AWS Lambda (Python ML processing)"

database:
  primary: "RDS PostgreSQL 15.x Multi-AZ"
  read_replicas: "RDS Read Replicas (2x)"
  cache: "ElastiCache Redis Cluster"

storage:
  files: "S3 Standard for reports/uploads"
  cdn: "CloudFront distribution"
  backups: "S3 Glacier for long-term retention"

networking:
  load_balancer: "Application Load Balancer"
  vpc: "Custom VPC with private/public subnets"
  dns: "Route 53 for domain management"

monitoring:
  logs: "CloudWatch Logs"
  metrics: "CloudWatch Metrics + Custom Dashboards"
  alarms: "CloudWatch Alarms + SNS notifications"
  tracing: "AWS X-Ray for request tracing"
```

#### Infrastructure as Code (Terraform)
```hcl
# main.tf - AWS Infrastructure
provider "aws" {
  region = var.aws_region
}

# VPC Configuration
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  
  name = "concrete-analyzer-vpc"
  cidr = "10.0.0.0/16"
  
  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  
  enable_nat_gateway = true
  enable_vpn_gateway = false
  enable_dns_hostnames = true
  enable_dns_support = true
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "concrete-analyzer-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets           = module.vpc.public_subnets
  
  enable_deletion_protection = true
}

# RDS PostgreSQL Database
resource "aws_db_instance" "main" {
  identifier = "concrete-analyzer-db"
  
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.r6g.large"
  
  allocated_storage     = 100
  max_allocated_storage = 1000
  storage_type         = "gp3"
  storage_encrypted    = true
  
  db_name  = "concrete_analyzer"
  username = var.db_username
  password = var.db_password
  
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  
  backup_retention_period = 30
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  multi_az               = true
  publicly_accessible    = false
  
  deletion_protection = true
  skip_final_snapshot = false
  final_snapshot_identifier = "concrete-analyzer-final-snapshot"
}

# ElastiCache Redis Cluster
resource "aws_elasticache_replication_group" "main" {
  replication_group_id       = "concrete-analyzer-redis"
  description                = "Redis cluster for concrete analyzer"
  
  node_type                  = "cache.r7g.large"
  port                       = 6379
  parameter_group_name       = "default.redis7"
  
  num_cache_clusters         = 3
  automatic_failover_enabled = true
  multi_az_enabled          = true
  
  subnet_group_name = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.redis.id]
  
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                = var.redis_auth_token
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "concrete-analyzer-cluster"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}
```

#### Application Deployment Configuration
```yaml
# docker-compose.production.yml
version: '3.8'

services:
  frontend:
    image: concrete-analyzer/frontend:${VERSION}
    build:
      context: ./frontend
      dockerfile: Dockerfile.production
    environment:
      - NODE_ENV=production
      - REACT_APP_API_URL=https://api.concreteanalyzer.com
    ports:
      - "80:80"
      - "443:443"
    restart: unless-stopped
    
  backend:
    image: concrete-analyzer/backend:${VERSION}
    build:
      context: ./backend
      dockerfile: Dockerfile.production
    environment:
      - NODE_ENV=production
      - DATABASE_URL=${DATABASE_URL}
      - REDIS_URL=${REDIS_URL}
      - JWT_SECRET=${JWT_SECRET}
      - AWS_REGION=${AWS_REGION}
    depends_on:
      - postgres
      - redis
    restart: unless-stopped
    
  analytics:
    image: concrete-analyzer/analytics:${VERSION}
    build:
      context: ./analytics
      dockerfile: Dockerfile.production
    environment:
      - PYTHON_ENV=production
      - DATABASE_URL=${DATABASE_URL}
      - REDIS_URL=${REDIS_URL}
    restart: unless-stopped
```

### Alternative: Azure Deployment

#### Azure Services Mapping
```yaml
compute:
  frontend: "Azure Container Instances (React)"
  backend: "Azure Container Instances (Node.js)"
  analytics: "Azure Functions (Python)"

database:
  primary: "Azure Database for PostgreSQL Flexible Server"
  cache: "Azure Cache for Redis"

storage:
  files: "Azure Blob Storage"
  cdn: "Azure CDN"

networking:
  load_balancer: "Azure Application Gateway"
  dns: "Azure DNS"

monitoring:
  logs: "Azure Monitor Logs"
  metrics: "Azure Monitor Metrics"
  alerts: "Azure Alerts"
```

### Alternative: Google Cloud Platform

#### GCP Services Mapping
```yaml
compute:
  frontend: "Cloud Run (React)"
  backend: "Cloud Run (Node.js)"
  analytics: "Cloud Functions (Python)"

database:
  primary: "Cloud SQL for PostgreSQL"
  cache: "Memorystore for Redis"

storage:
  files: "Cloud Storage"
  cdn: "Cloud CDN"

networking:
  load_balancer: "Cloud Load Balancing"
  dns: "Cloud DNS"

monitoring:
  logs: "Cloud Logging"
  metrics: "Cloud Monitoring"
  alerts: "Cloud Alerting"
```

## Container Configuration

### Frontend Dockerfile
```dockerfile
# frontend/Dockerfile.production
FROM node:18-alpine AS build

WORKDIR /app

# Copy package files
COPY package*.json ./
RUN npm ci --only=production

# Copy source code
COPY . .

# Build application
RUN npm run build

# Production stage
FROM nginx:1.24-alpine

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy built application
COPY --from=build /app/build /usr/share/nginx/html

# Add healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost/health || exit 1

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### Backend Dockerfile
```dockerfile
# backend/Dockerfile.production
FROM node:18-alpine AS build

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copy source code
COPY . .

# Build TypeScript
RUN npm run build

# Production stage
FROM node:18-alpine

WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001

# Copy built application and dependencies
COPY --from=build --chown=nodejs:nodejs /app/dist ./dist
COPY --from=build --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=build --chown=nodejs:nodejs /app/package.json ./

# Add healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

USER nodejs

EXPOSE 3000
CMD ["node", "dist/index.js"]
```

### Analytics Service Dockerfile
```dockerfile
# analytics/Dockerfile.production
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create non-root user
RUN useradd -m -u 1001 analytics
RUN chown -R analytics:analytics /app
USER analytics

# Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

EXPOSE 8000
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "4", "app:app"]
```

## CI/CD Pipeline

### GitHub Actions Workflow
```yaml
# .github/workflows/deploy.yml
name: Deploy to Production

on:
  push:
    branches: [main]
  workflow_dispatch:

env:
  AWS_REGION: us-east-1
  ECR_REGISTRY: 123456789012.dkr.ecr.us-east-1.amazonaws.com

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: |
          npm ci --prefix backend
          npm ci --prefix frontend
      
      - name: Run tests
        run: |
          npm run test --prefix backend
          npm run test --prefix frontend
      
      - name: Run linting
        run: |
          npm run lint --prefix backend
          npm run lint --prefix frontend
      
      - name: Type checking
        run: |
          npm run type-check --prefix backend
          npm run type-check --prefix frontend

  build:
    needs: test
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service: [frontend, backend, analytics]
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Login to Amazon ECR
        uses: aws-actions/amazon-ecr-login@v2
      
      - name: Build and push Docker image
        run: |
          IMAGE_TAG=${GITHUB_SHA:0:8}
          docker build -f ${{ matrix.service }}/Dockerfile.production \
            -t ${{ env.ECR_REGISTRY }}/${{ matrix.service }}:$IMAGE_TAG \
            -t ${{ env.ECR_REGISTRY }}/${{ matrix.service }}:latest \
            ${{ matrix.service }}
          docker push ${{ env.ECR_REGISTRY }}/${{ matrix.service }}:$IMAGE_TAG
          docker push ${{ env.ECR_REGISTRY }}/${{ matrix.service }}:latest

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment: production
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Deploy to ECS
        run: |
          IMAGE_TAG=${GITHUB_SHA:0:8}
          
          # Update ECS service definitions
          aws ecs update-service \
            --cluster concrete-analyzer-cluster \
            --service concrete-analyzer-backend \
            --task-definition concrete-analyzer-backend:$IMAGE_TAG \
            --force-new-deployment
          
          aws ecs update-service \
            --cluster concrete-analyzer-cluster \
            --service concrete-analyzer-frontend \
            --task-definition concrete-analyzer-frontend:$IMAGE_TAG \
            --force-new-deployment
      
      - name: Wait for deployment
        run: |
          aws ecs wait services-stable \
            --cluster concrete-analyzer-cluster \
            --services concrete-analyzer-backend concrete-analyzer-frontend
      
      - name: Run smoke tests
        run: |
          ./scripts/smoke-tests.sh https://api.concreteanalyzer.com
      
      - name: Notify deployment success
        uses: 8398a7/action-slack@v3
        with:
          status: success
          text: "✅ Concrete Analyzer deployed successfully to production"
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

### Database Migration Strategy
```bash
#!/bin/bash
# scripts/deploy-migrations.sh

set -e

echo "Starting database migration deployment..."

# Create backup before migration
echo "Creating database backup..."
aws rds create-db-snapshot \
  --db-instance-identifier concrete-analyzer-db \
  --db-snapshot-identifier "pre-migration-$(date +%Y%m%d-%H%M%S)"

# Wait for backup to complete
aws rds wait db-snapshot-completed \
  --db-snapshot-identifier "pre-migration-$(date +%Y%m%d-%H%M%S)"

# Run migrations
echo "Running database migrations..."
npm run migrate --prefix backend

# Verify migration success
echo "Verifying migration..."
npm run migrate:verify --prefix backend

echo "Migration completed successfully!"
```

## Monitoring and Observability

### Application Monitoring
```yaml
# monitoring/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "concrete_analyzer_rules.yml"

scrape_configs:
  - job_name: 'concrete-analyzer-backend'
    static_configs:
      - targets: ['backend:3000']
    metrics_path: '/metrics'
    scrape_interval: 10s
    
  - job_name: 'concrete-analyzer-frontend'
    static_configs:
      - targets: ['frontend:80']
    metrics_path: '/metrics'
    scrape_interval: 30s

  - job_name: 'postgresql'
    static_configs:
      - targets: ['postgres-exporter:9187']
    scrape_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093
```

### Custom Metrics and Alerts
```yaml
# monitoring/concrete_analyzer_rules.yml
groups:
  - name: concrete_analyzer_alerts
    rules:
      - alert: HighResponseTime
        expr: http_request_duration_seconds{quantile="0.95"} > 0.5
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High response time detected"
          description: "95th percentile response time is {{ $value }}s"
      
      - alert: LowProfitMargin
        expr: avg_profit_margin < 15
        for: 10m
        labels:
          severity: critical
        annotations:
          summary: "Profit margins below threshold"
          description: "Average profit margin is {{ $value }}%"
      
      - alert: DatabaseConnectionFailure
        expr: up{job="postgresql"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Database connection failed"
          description: "PostgreSQL database is not responding"
      
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value }} requests/second"
```

### Logging Configuration
```yaml
# logging/filebeat.yml
filebeat.inputs:
  - type: container
    paths:
      - '/var/lib/docker/containers/*/*.log'
    processors:
      - add_docker_metadata:
          host: "unix:///var/run/docker.sock"

output.elasticsearch:
  hosts: ["elasticsearch:9200"]
  index: "concrete-analyzer-logs-%{+yyyy.MM.dd}"

logging.level: info
```

## Security Configuration

### SSL/TLS Configuration
```nginx
# nginx/ssl.conf
server {
    listen 443 ssl http2;
    server_name concreteanalyzer.com www.concreteanalyzer.com;
    
    # SSL Configuration
    ssl_certificate /etc/ssl/certs/concreteanalyzer.com.crt;
    ssl_certificate_key /etc/ssl/private/concreteanalyzer.com.key;
    
    # Modern SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Content Security Policy
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' https://api.concreteanalyzer.com;" always;
    
    location / {
        proxy_pass http://frontend:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Environment Variables Security
```bash
# scripts/setup-secrets.sh
#!/bin/bash

# Create AWS Secrets Manager secrets
aws secretsmanager create-secret \
  --name "concrete-analyzer/database" \
  --description "Database credentials for Concrete Analyzer" \
  --secret-string '{
    "username": "concrete_user",
    "password": "'$(openssl rand -base64 32)'",
    "host": "concrete-analyzer-db.cluster-xyz.us-east-1.rds.amazonaws.com",
    "port": 5432,
    "database": "concrete_analyzer"
  }'

aws secretsmanager create-secret \
  --name "concrete-analyzer/jwt" \
  --description "JWT secrets for Concrete Analyzer" \
  --secret-string '{
    "access_token_secret": "'$(openssl rand -base64 64)'",
    "refresh_token_secret": "'$(openssl rand -base64 64)'"
  }'

aws secretsmanager create-secret \
  --name "concrete-analyzer/redis" \
  --description "Redis credentials for Concrete Analyzer" \
  --secret-string '{
    "auth_token": "'$(openssl rand -base64 32)'",
    "host": "concrete-analyzer-redis.cache.amazonaws.com",
    "port": 6379
  }'
```

## Backup and Disaster Recovery

### Automated Backup Strategy
```bash
#!/bin/bash
# scripts/backup-strategy.sh

# Database backup
create_db_backup() {
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  BACKUP_NAME="concrete-analyzer-backup-${TIMESTAMP}"
  
  # Create RDS snapshot
  aws rds create-db-snapshot \
    --db-instance-identifier concrete-analyzer-db \
    --db-snapshot-identifier $BACKUP_NAME
    
  # Export to S3 for cross-region backup
  aws rds start-export-task \
    --export-task-identifier $BACKUP_NAME \
    --source-arn $(aws rds describe-db-snapshots \
      --db-snapshot-identifier $BACKUP_NAME \
      --query 'DBSnapshots[0].DBSnapshotArn' --output text) \
    --s3-bucket-name concrete-analyzer-backups \
    --s3-prefix "database-exports/$BACKUP_NAME" \
    --iam-role-arn arn:aws:iam::123456789012:role/rds-s3-export-role \
    --kms-key-id arn:aws:kms:us-east-1:123456789012:key/key-id
}

# Application files backup
backup_app_files() {
  aws s3 sync s3://concrete-analyzer-uploads \
    s3://concrete-analyzer-backups/uploads/$(date +%Y%m%d) \
    --storage-class GLACIER
}

# Configuration backup
backup_configurations() {
  kubectl get secrets,configmaps -o yaml > /tmp/k8s-configs.yaml
  aws s3 cp /tmp/k8s-configs.yaml \
    s3://concrete-analyzer-backups/configurations/$(date +%Y%m%d)/
}

# Execute backups
create_db_backup
backup_app_files
backup_configurations
```

### Disaster Recovery Plan
```yaml
# disaster-recovery/recovery-plan.yml
recovery_procedures:
  rto: 4 hours  # Recovery Time Objective
  rpo: 1 hour   # Recovery Point Objective
  
  steps:
    1_assessment:
      - "Evaluate scope of outage"
      - "Check backup integrity"
      - "Notify stakeholders"
    
    2_infrastructure:
      - "Deploy infrastructure in DR region"
      - "Restore database from latest backup"
      - "Configure networking and security"
    
    3_application:
      - "Deploy application containers"
      - "Restore application data from S3"
      - "Update DNS to point to DR environment"
    
    4_validation:
      - "Run smoke tests"
      - "Verify data integrity"
      - "Confirm user access"
    
    5_communication:
      - "Notify users of service restoration"
      - "Update status page"
      - "Document incident"

failover_triggers:
  - "Database unavailability > 15 minutes"
  - "Application error rate > 50% for 10 minutes"
  - "Regional AWS service outage"
  - "Manual failover request from operations team"
```

## Performance Optimization

### Database Optimization
```sql
-- performance/optimization.sql

-- Create materialized view for dashboard data
CREATE MATERIALIZED VIEW dashboard_summary AS
SELECT 
  DATE_TRUNC('day', sale_date) as day,
  COUNT(*) as total_sales,
  SUM(concrete_yards) as total_yards,
  SUM(total_revenue) as total_revenue,
  AVG(profit_margin) as avg_margin
FROM sales 
WHERE sale_date >= CURRENT_DATE - INTERVAL '30 days'
  AND delivery_status = 'delivered'
GROUP BY DATE_TRUNC('day', sale_date)
ORDER BY day DESC;

-- Create index for common query patterns
CREATE INDEX CONCURRENTLY idx_sales_analysis 
ON sales (sale_date, customer_id, profit_margin) 
WHERE delivery_status = 'delivered';

CREATE INDEX CONCURRENTLY idx_costs_project_category 
ON costs (project_id, cost_category, cost_date);

-- Refresh materialized view automatically
CREATE OR REPLACE FUNCTION refresh_dashboard_summary()
RETURNS trigger AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY dashboard_summary;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_refresh_dashboard
  AFTER INSERT OR UPDATE OR DELETE ON sales
  FOR EACH STATEMENT
  EXECUTE FUNCTION refresh_dashboard_summary();
```

### Application Optimization
```typescript
// performance/caching.ts
import Redis from 'ioredis';

class PerformanceOptimizer {
  private redis: Redis;
  
  constructor() {
    this.redis = new Redis(process.env.REDIS_URL);
  }
  
  // Cache frequently accessed data
  async getCachedProfitAnalysis(dateRange: string): Promise<any> {
    const cacheKey = `profit:analysis:${dateRange}`;
    const cached = await this.redis.get(cacheKey);
    
    if (cached) {
      return JSON.parse(cached);
    }
    
    // Fetch from database
    const data = await this.fetchProfitAnalysis(dateRange);
    
    // Cache for 5 minutes
    await this.redis.setex(cacheKey, 300, JSON.stringify(data));
    
    return data;
  }
  
  // Preload common queries
  async preloadDashboardData(): Promise<void> {
    const commonRanges = ['7days', '30days', '3months'];
    
    await Promise.all(
      commonRanges.map(range => 
        this.getCachedProfitAnalysis(range)
      )
    );
  }
}
```

This deployment guide provides a comprehensive production-ready infrastructure setup for the concrete sales and profit analyzer with security, monitoring, and disaster recovery best practices.