# Phase 49: Quick Start Guide
## OmniBus Enterprise API Gateway

---

## 🚀 5-Minute Local Setup

### 1. Prerequisites

```bash
# Install Docker & Docker Compose
sudo apt-get install docker.io docker-compose

# Verify installation
docker --version
docker-compose --version
```

### 2. Start Services (Docker)

```bash
cd docker
docker-compose up -d

# Wait for Redis to be ready
sleep 10

# Verify services are running
docker-compose ps
```

Output should show:
```
NAME                    STATUS
omnibus-redis          Up (healthy)
omnibus-api-gateway    Up
omnibus-nginx          Up
```

### 3. Test API Gateway

```bash
# Health check
curl http://localhost:8000/health

# Expected response:
# {"status":"healthy","version":"1.0.0",...}
```

### 4. Access Dashboard

```bash
# Open in browser
open http://localhost/dashboard_scaled.html

# Or via curl
curl http://localhost/dashboard_scaled.html | head -20
```

### 5. Submit Test Order

```bash
# Get API key from response
curl -X POST http://localhost:8000/orders/submit \
  -H "X-API-Key: test_user_abc123def456" \
  -H "Content-Type: application/json" \
  -d '{
    "pair": "BTC-USD",
    "side": "BUY",
    "price_cents": 7160000,
    "quantity": 0.1,
    "exchange": "kraken"
  }' | jq .

# Expected response:
# {"order_id":"test_user_..._123456","status":"SUBMITTED","message":"Order submitted successfully"}
```

---

## ⚙️ Configuration

### Change API Port

Edit `docker/docker-compose.yml`:
```yaml
services:
  api-gateway:
    ports:
      - "9000:8000"  # Changed from 8000
```

### Change Redis Configuration

Edit `docker/docker-compose.yml`:
```yaml
services:
  redis:
    command: redis-server --maxmemory 4gb --maxmemory-policy allkeys-lru
```

### Enable Persistent Storage

Edit `docker/docker-compose.yml`:
```yaml
volumes:
  redis-data:
    driver: local
    driver_opts:
      type: nfs
      o: addr=nfs-server.local,vers=4,soft,timeo=180,bg,tcp,rw
      device: ":/export/redis"
```

---

## 📊 Monitoring (Local)

### Redis Stats

```bash
# Connect to Redis CLI
docker exec -it omnibus-redis redis-cli

# View memory usage
INFO memory

# View operations count
INFO stats

# Monitor in real-time
MONITOR
```

### API Gateway Logs

```bash
# Follow logs
docker logs -f omnibus-api-gateway

# View last 100 lines
docker logs --tail 100 omnibus-api-gateway
```

### API Metrics

```bash
# Prometheus format metrics
curl http://localhost:8000/metrics

# Expected output:
# active_connections 0
# active_users 0
# timestamp 1710115200.123
```

---

## 🧪 Load Testing

### 100 Concurrent Requests

```bash
# Using Apache Bench
ab -n 1000 -c 100 http://localhost:8000/health

# Using wrk (better for sustained load)
wrk -t 4 -c 100 -d 30s --latency http://localhost:8000/health
```

### WebSocket Stress Test

```bash
# Using wscat
npm install -g wscat

wscat -c ws://localhost:8000/ws/prices/kraken?token=test

# Keep connection open and monitor message rate
```

### Order Submission Load Test

```bash
#!/bin/bash

# Submit 100 orders in parallel
for i in {1..100}; do
  curl -X POST http://localhost:8000/orders/submit \
    -H "X-API-Key: user_$i" \
    -H "Content-Type: application/json" \
    -d '{
      "pair": "BTC-USD",
      "side": "BUY",
      "price_cents": 7160000,
      "quantity": 0.1,
      "exchange": "kraken"
    }' &
done

wait
echo "All orders submitted"
```

---

## ☸️ Kubernetes Quick Start

### 1. Create Local K8s Cluster

```bash
# Using Kind (Kubernetes in Docker)
kind create cluster --name omnibus

# Or using Minikube
minikube start --cpus 4 --memory 8192

# Verify cluster
kubectl get nodes
```

### 2. Create Registry Secret

```bash
# If using private Docker registry
kubectl create secret docker-registry regcred \
  --docker-server=registry.example.com \
  --docker-username=user \
  --docker-password=password \
  -n omnibus
```

### 3. Deploy Namespace

```bash
kubectl apply -f k8s/omnibus-namespace.yaml

# Verify
kubectl get namespace omnibus
```

### 4. Deploy Redis

```bash
kubectl apply -f k8s/redis-statefulset.yaml

# Wait for ready
kubectl wait --for=condition=Ready pod -l app=redis -n omnibus --timeout=300s

# Verify
kubectl get statefulset redis -n omnibus
kubectl get pvc -n omnibus
```

### 5. Deploy API Gateway

```bash
kubectl apply -f k8s/api-gateway-deployment.yaml

# Monitor deployment
kubectl rollout status deployment/api-gateway -n omnibus

# Verify replicas
kubectl get replicas -n omnibus
```

### 6. Deploy Monitoring

```bash
kubectl apply -f k8s/prometheus-monitoring.yaml

# Access Prometheus
kubectl port-forward svc/prometheus 9090:9090 -n omnibus
# Visit: http://localhost:9090
```

### 7. Deploy Ingress

```bash
kubectl apply -f k8s/ingress.yaml

# Get load balancer IP
kubectl get svc nginx-lb -n omnibus

# Test ingress
curl http://<load-balancer-ip>/health
```

---

## 📈 Scaling Commands

### Manual Scaling

```bash
# Scale to 50 replicas
kubectl scale deployment api-gateway --replicas=50 -n omnibus

# Scale to 500 replicas (for 100M users)
kubectl scale deployment api-gateway --replicas=500 -n omnibus

# Check scaling progress
kubectl get deploy api-gateway -n omnibus -o wide
```

### Auto-Scaling Status

```bash
# View HPA (Horizontal Pod Autoscaler)
kubectl get hpa -n omnibus

# Watch scaling decisions
kubectl get hpa -n omnibus -w

# Detailed HPA info
kubectl describe hpa api-gateway-hpa -n omnibus
```

### Check Pod Distribution

```bash
# Show all pods with node assignment
kubectl get pods -n omnibus -o wide

# Count pods per node
kubectl get pods -n omnibus -o wide | awk '{print $7}' | sort | uniq -c
```

---

## 🔍 Debugging

### Check API Gateway Logs

```bash
# Docker
docker logs omnibus-api-gateway

# Kubernetes
kubectl logs deployment/api-gateway -n omnibus -f

# Specific pod
kubectl logs api-gateway-xxxx -n omnibus
```

### Check Redis Connection

```bash
# Docker
docker exec omnibus-redis redis-cli ping

# Kubernetes
kubectl exec -it redis-0 -n omnibus -- redis-cli ping
```

### Test WebSocket Connection

```bash
# Using websocat (install: cargo install websocat)
websocat ws://localhost:8000/ws/prices/kraken?token=test

# Or using JavaScript in browser console:
ws = new WebSocket('ws://localhost:8000/ws/prices/kraken?token=test');
ws.onmessage = (e) => console.log(JSON.parse(e.data));
```

### Network Debugging

```bash
# Check service endpoints
kubectl get endpoints api-gateway -n omnibus

# DNS resolution
kubectl exec -it <pod> -n omnibus -- nslookup redis.omnibus.svc.cluster.local

# Network policies
kubectl get networkpolicy -n omnibus
```

---

## 🛑 Cleanup

### Docker Cleanup

```bash
# Stop services
docker-compose down

# Remove volumes
docker-compose down -v

# Remove images
docker rmi omnibus/api-gateway:latest
```

### Kubernetes Cleanup

```bash
# Delete namespace (deletes all resources)
kubectl delete namespace omnibus

# Or delete specific resources
kubectl delete -f k8s/

# Verify cleanup
kubectl get all -n omnibus
```

---

## 📞 Troubleshooting

### "Connection refused" to API Gateway

```bash
# Check if service is running
docker ps | grep api-gateway

# Check logs
docker logs omnibus-api-gateway

# Try manually starting
docker-compose up api-gateway
```

### "Redis connection timeout"

```bash
# Check if Redis is running
docker ps | grep redis

# Check Redis logs
docker logs omnibus-redis

# Test Redis connectivity
docker exec omnibus-api-gateway redis-cli -h redis ping
```

### High Memory Usage

```bash
# Docker: Check container stats
docker stats omnibus-redis

# Kubernetes: Check pod resources
kubectl top pod -n omnibus

# Reduce maxmemory in Redis
docker exec omnibus-redis redis-cli CONFIG SET maxmemory 4gb
```

### WebSocket Connection Drops

```bash
# Increase connection timeout in nginx
proxy_read_timeout 3600s;
proxy_send_timeout 3600s;

# Reload nginx
docker exec omnibus-nginx nginx -s reload

# Check nginx logs
docker logs omnibus-nginx
```

---

## 📚 Next Steps

1. **Production Deployment**
   - Follow `PHASE_49_ENTERPRISE_SCALING.md` for full production guide
   - Deploy to cloud (AWS, GCP, Azure)
   - Configure DNS and TLS certificates

2. **Performance Optimization**
   - Run load tests (see above)
   - Monitor metrics (Prometheus)
   - Tune Redis and Nginx configs

3. **Integration with OmniBus**
   - Connect API Gateway to real bare-metal OmniBus
   - Replace mock price data with real market feeds
   - Implement order routing to OmniBus kernel

4. **Scale to 1 Billion Users**
   - Deploy 1000 API Gateway replicas
   - Shard Redis across multiple clusters
   - Implement multi-region failover

---

**Quick Start Version**: 1.0
**Last Updated**: 2026-03-11
**For Full Docs**: See `PHASE_49_ENTERPRISE_SCALING.md`
