# Kubernetes Deployment

## KServe Integration

Deploy RxInferKServe.jl as a KServe InferenceService:

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: rxinfer-model
  namespace: default
spec:
  predictor:
    containers:
    - name: kserve-container
      image: ghcr.io/pteradigm/rxinferkserve:latest
      ports:
      - containerPort: 8080
        name: http1
        protocol: TCP
      - containerPort: 8081
        name: grpc
        protocol: TCP
      env:
      - name: RXINFER_LOG_LEVEL
        value: "info"
      resources:
        requests:
          memory: "2Gi"
          cpu: "1"
        limits:
          memory: "4Gi"
          cpu: "2"
```

## Standalone Deployment

### Basic Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rxinfer-server
  labels:
    app: rxinfer
spec:
  replicas: 3
  selector:
    matchLabels:
      app: rxinfer
  template:
    metadata:
      labels:
        app: rxinfer
    spec:
      containers:
      - name: rxinfer
        image: ghcr.io/pteradigm/rxinferkserve:latest
        ports:
        - containerPort: 8080
          name: http
        - containerPort: 8081
          name: grpc
        env:
        - name: RXINFER_API_KEY
          valueFrom:
            secretKeyRef:
              name: rxinfer-secrets
              key: api-key
        livenessProbe:
          httpGet:
            path: /v2/health/live
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /v2/health/ready
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
```

### Service Configuration

```yaml
apiVersion: v1
kind: Service
metadata:
  name: rxinfer-service
spec:
  selector:
    app: rxinfer
  ports:
  - name: http
    port: 80
    targetPort: 8080
  - name: grpc
    port: 8081
    targetPort: 8081
  type: LoadBalancer
```

## Horizontal Pod Autoscaling

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: rxinfer-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: rxinfer-server
  minReplicas: 2
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
```

## ConfigMaps and Secrets

### ConfigMap for Model Configuration

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: rxinfer-config
data:
  server-config.toml: |
    [server]
    host = "0.0.0.0"
    port = 8080
    grpc_port = 8081
    workers = 4
    
    [logging]
    level = "info"
    format = "json"
```

### Secret for API Keys

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: rxinfer-secrets
type: Opaque
stringData:
  api-key: "your-secret-api-key"
```

## Ingress Configuration

### HTTP Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rxinfer-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: rxinfer.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: rxinfer-service
            port:
              number: 80
  tls:
  - hosts:
    - rxinfer.example.com
    secretName: rxinfer-tls
```

### gRPC Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rxinfer-grpc-ingress
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "GRPC"
spec:
  rules:
  - host: grpc.rxinfer.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: rxinfer-service
            port:
              number: 8081
```

## Persistent Storage

Mount models from persistent volumes:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: rxinfer-models-pvc
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
---
# In deployment spec:
volumes:
- name: models
  persistentVolumeClaim:
    claimName: rxinfer-models-pvc
volumeMounts:
- name: models
  mountPath: /app/models
```

## Monitoring with Prometheus

### ServiceMonitor for Prometheus Operator

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: rxinfer-metrics
spec:
  selector:
    matchLabels:
      app: rxinfer
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
```

## Best Practices

### 1. Resource Management

- Set appropriate resource requests and limits
- Use HPA for automatic scaling
- Consider using VPA for right-sizing

### 2. High Availability

- Run multiple replicas (minimum 3)
- Use pod disruption budgets
- Implement proper health checks

### 3. Security

- Use network policies
- Enable RBAC
- Store secrets in Kubernetes secrets
- Use service mesh for mTLS

### 4. Observability

- Centralized logging with Fluentd/Fluentbit
- Metrics with Prometheus
- Distributed tracing with Jaeger
- Dashboards with Grafana

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -l app=rxinfer
kubectl describe pod rxinfer-server-xxx
kubectl logs rxinfer-server-xxx
```

### Test Service Connectivity

```bash
# Port forward for testing
kubectl port-forward svc/rxinfer-service 8080:80

# Test from another pod
kubectl run test --rm -it --image=curlimages/curl -- sh
curl http://rxinfer-service/v2/health/ready
```

### Debug with Executive Shell

```bash
kubectl exec -it rxinfer-server-xxx -- julia
```