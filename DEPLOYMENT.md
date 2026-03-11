# OmniBus Deployment Guide

## Overview

OmniBus API Gateway can be deployed in three environments:

1. **Local Development** - Docker Compose (single-machine)
2. **Kubernetes** - Production-grade (cloud/on-prem)
3. **Bare Metal** - Direct Python execution

---

## 1. Docker Compose (Local Development)

### Prerequisites
- Docker >= 20.10
- Docker Compose >= 2.0

### Quick Start

```bash
# Build and start stack
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f api

# Test API
curl http://localhost:8000/health

# Open dashboard
# Browser: http://localhost:8000/market-profile.html
# Browser: http://localhost:8000/profiler.html
```

### Services Started

```
omnibus-redis  → Redis cache on 6379
omnibus-api    → FastAPI on 8000
omnibus-nginx  → Reverse proxy on 80
```

### Environment Variables

Set in `docker-compose.yml`:
- `REDIS_HOST`: Redis hostname (default: redis)
- `REDIS_PORT`: Redis port (default: 6379)
- `API_VERSION`: API version string

### Teardown

```bash
docker-compose down
docker-compose down -v  # Also remove volumes
```

---

## 2. Kubernetes Deployment

### Prerequisites

- Kubernetes cluster >= 1.20
- kubectl configured
- Docker image pushed to registry
- Ingress controller (e.g., nginx-ingress)
- Cert-manager (for TLS certificates)

### Deploy to Kubernetes

```bash
# Create namespace and deploy
kubectl apply -f k8s-deployment.yaml

# Check deployment status
kubectl get deployment -n omnibus-production
kubectl get pods -n omnibus-production

# View logs
kubectl logs -n omnibus-production -l app=omnibus-api -f

# Port forward for testing
kubectl port-forward -n omnibus-production svc/omnibus-api-service 8000:8000
```

### What Gets Deployed

```
Namespace: omnibus-production
├─ Redis StatefulSet (1 replica, persistent storage)
├─ OmniBus API Deployment (3 replicas)
├─ Services (redis-service, omnibus-api-service)
├─ HorizontalPodAutoscaler (3-10 replicas based on CPU/memory)
├─ Ingress (api.omnibus.trading → omnibus-api-service:8000)
├─ ServiceAccount + RBAC roles
└─ ConfigMap (API configuration)
```

### Configuration

Edit in `k8s-deployment.yaml`:

| Setting | Location | Default |
|---------|----------|---------|
| Replicas | Deployment.spec.replicas | 3 |
| Min/Max replicas | HPA.spec.min/maxReplicas | 3 / 10 |
| Memory request | Deployment container.resources.requests | 512Mi |
| Memory limit | Deployment container.resources.limits | 1Gi |
| Ingress host | Ingress.spec.rules[0].host | api.omnibus.trading |

### Scaling

```bash
# Manual scaling
kubectl scale deployment -n omnibus-production omnibus-api --replicas=5

# Check HPA status
kubectl get hpa -n omnibus-production

# Watch auto-scaling
kubectl get hpa -n omnibus-production -w
```

### Monitoring

```bash
# Get pod metrics (requires metrics-server)
kubectl top pods -n omnibus-production

# Check events
kubectl get events -n omnibus-production

# Debug pod
kubectl exec -it -n omnibus-production <pod-name> -- /bin/sh
```

### Remove Deployment

```bash
kubectl delete namespace omnibus-production
```

---

## 3. Bare Metal (Direct Python)

### Prerequisites

- Python 3.11+
- pip
- Redis server running (e.g., `redis-server`)

### Install & Run

```bash
# Install dependencies
cd OmniBus/services
pip install -r requirements.txt

# Start API gateway
python3 omnibus_api_gateway.py

# Server runs on http://localhost:8000
```

### Configuration

Edit environment variables before running:

```bash
export REDIS_HOST=localhost
export REDIS_PORT=6379
export API_VERSION=1.0.0
python3 omnibus_api_gateway.py
```

---

## 4. Nginx Reverse Proxy Configuration

The nginx reverse proxy (in Docker Compose) provides:

- **Load balancing**: Round-robin to API instances
- **Rate limiting**: 100 req/s for API, 10 req/s for WebSocket
- **Compression**: Gzip enabled for JSON responses
- **Security headers**: X-Frame-Options, X-Content-Type-Options, etc.
- **WebSocket support**: Upgrade headers for /ws/* endpoints
- **SSL/TLS**: Ready for HTTPS (certificates needed)

### Enable HTTPS

```bash
# Place certificate files
cp /path/to/cert.pem certs/cert.pem
cp /path/to/key.pem certs/key.pem

# Uncomment SSL directives in nginx.conf
# Restart: docker-compose restart nginx
```

---

## 5. Health Checks

All deployments include health checks:

```bash
# REST endpoint (all deployments)
curl http://localhost:8000/health

# Kubernetes liveness probe
GET /health (port 8000)
Initial delay: 30s
Period: 10s
Timeout: 5s
Failures: 3

# Kubernetes readiness probe
GET /health (port 8000)
Initial delay: 10s
Period: 5s
Timeout: 3s
Failures: 2
```

---

## 6. API Endpoints

### Market Profile (OHLCV)

```bash
# REST endpoints
curl http://localhost:8000/api/ohlcv/btc
curl http://localhost:8000/api/ohlcv/eth
curl http://localhost:8000/api/ohlcv/lcx
curl http://localhost:8000/api/market-matrix

# WebSocket streams (browser console)
const ws = new WebSocket('ws://localhost:8000/ws/ohlcv/btc');
ws.onmessage = (msg) => console.log(JSON.parse(msg.data));
```

### Performance Profiler

```bash
# REST endpoints
curl http://localhost:8000/api/profiler/summary
curl http://localhost:8000/api/profiler/module/0
curl http://localhost:8000/api/profiler/modules/10

# Dashboard
# Browser: http://localhost:8000/profiler.html
```

### Tick Streams

```bash
# WebSocket real-time price updates
const ws = new WebSocket('ws://localhost:8000/ws/prices/kraken');
ws.onmessage = (msg) => console.log(JSON.parse(msg.data));

# Supported exchanges: kraken, coinbase, lcx, all
```

---

## 7. Performance Tuning

### Kubernetes Pod Limits

For high-throughput (10,000+ req/s):

```yaml
resources:
  requests:
    memory: "1Gi"
    cpu: "2000m"
  limits:
    memory: "2Gi"
    cpu: "4000m"
```

### Redis Configuration

For persistence:

```bash
docker-compose.yml:
command: redis-server --appendonly yes --maxmemory 1gb --maxmemory-policy allkeys-lru
```

### Nginx Tuning

```nginx
worker_connections 10000;  # Increase for more concurrent connections
upstream omnibus_api {
    least_conn;  # Load balancing strategy
    server api1:8000 weight=5;
    server api2:8000 weight=3;
}
```

---

## 8. Monitoring & Logging

### Docker Compose Logs

```bash
docker-compose logs -f api
docker-compose logs -f redis
docker-compose logs -f nginx
```

### Kubernetes Logs

```bash
kubectl logs -n omnibus-production -l app=omnibus-api
kubectl logs -n omnibus-production -l app=redis
kubectl logs -n omnibus-production deployment/omnibus-api
```

### Prometheus Metrics

API exposes Prometheus metrics at `/metrics`:

```bash
curl http://localhost:8000/metrics
```

---

## 9. Troubleshooting

### API not responding

```bash
# Check container status
docker-compose ps

# Check logs for errors
docker-compose logs api

# Test health endpoint
curl -v http://localhost:8000/health
```

### Redis connection issues

```bash
# Test Redis directly
docker-compose exec redis redis-cli ping

# Check Redis memory
docker-compose exec redis redis-cli INFO memory
```

### WebSocket connection failures

```bash
# Test WebSocket (using wscat or similar)
wscat -c ws://localhost:8000/ws/ohlcv/btc

# Check nginx WebSocket config (should have Upgrade headers)
```

### Out of memory

```bash
# Increase limits in docker-compose.yml or k8s-deployment.yaml
# Monitor memory usage
docker stats
# or
kubectl top pods -n omnibus-production
```

---

## 10. Production Checklist

- [ ] SSL/TLS certificates configured
- [ ] Redis persistence enabled
- [ ] Kubernetes resource limits set
- [ ] HPA min/max replicas tuned
- [ ] Ingress hostname configured
- [ ] Monitoring/alerting set up
- [ ] Backup strategy for Redis data
- [ ] Log aggregation configured
- [ ] Rate limiting adjusted for expected load
- [ ] Health checks verified

---

**Last Updated**: 2026-03-11
**Version**: 1.0.0
