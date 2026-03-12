# OmniBus Configuration Files

Container and deployment configuration files.

## Files

- **Dockerfile** - Docker image definition for OmniBus runtime
- **docker-compose.yml** - Multi-container Docker setup
- **k8s-deployment.yaml** - Kubernetes deployment manifest
- **nginx.conf** - Nginx reverse proxy configuration

## Usage

### Docker
```bash
docker-compose -f configs/docker-compose.yml up
```

### Kubernetes
```bash
kubectl apply -f configs/k8s-deployment.yaml
```

### Nginx
```bash
nginx -c configs/nginx.conf
```
