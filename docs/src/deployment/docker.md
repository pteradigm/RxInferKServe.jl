# Docker Deployment

## Quick Start

Pull and run the pre-built image:

```bash
docker run -p 8080:8080 -p 8081:8081 ghcr.io/pteradigm/rxinferkserve:latest
```

## Building Custom Images

### Basic Dockerfile

```dockerfile
FROM julia:1.11

WORKDIR /app

# Copy project files
COPY Project.toml Manifest.toml ./
COPY src ./src

# Install dependencies
RUN julia --project=. -e 'using Pkg; Pkg.instantiate()'

# Build system image for fast startup
COPY scripts/build_sysimage.jl ./scripts/
RUN julia --project=. scripts/build_sysimage.jl

# Expose ports
EXPOSE 8080 8081

# Run with system image
CMD ["julia", "--sysimage=rxinfer_server.so", "--project=.", "-e", "using RxInferKServe; start_server(host=\"0.0.0.0\")"]
```

### Multi-stage Build

The provided Dockerfile uses multi-stage builds for optimal image size:

```bash
# Build the image
docker build -f docker/Dockerfile -t rxinferkserve:custom .

# Run with environment variables
docker run -p 8080:8080 \
  -e RXINFER_API_KEY=secret \
  -e RXINFER_LOG_LEVEL=debug \
  rxinferkserve:custom
```

## Docker Compose

Deploy with related services:

```yaml
version: '3.8'

services:
  rxinfer:
    image: ghcr.io/pteradigm/rxinferkserve:latest
    ports:
      - "8080:8080"
      - "8081:8081"
    environment:
      - RXINFER_API_KEY=${API_KEY}
      - RXINFER_LOG_LEVEL=info
    volumes:
      - ./models:/app/models
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/v2/health/ready"]
      interval: 30s
      timeout: 10s
      retries: 3

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
```

## Environment Variables

Configure the server using environment variables:

- `RXINFER_HOST`: Server host (default: "0.0.0.0")
- `RXINFER_PORT`: HTTP port (default: 8080)
- `RXINFER_GRPC_PORT`: gRPC port (default: 8081)
- `RXINFER_API_KEY`: API key for authentication
- `RXINFER_LOG_LEVEL`: Log level (debug, info, warn, error)
- `RXINFER_WORKERS`: Number of worker processes

## Volume Mounts

### Mounting Custom Models

To use custom models with the container:

1. **Create a models directory** with your Julia model files:
```bash
mkdir -p models
cat > models/custom_model.jl << 'EOF'
using RxInfer

@model function custom_model(x, y)
    θ ~ Beta(1.0, 1.0)
    σ ~ Gamma(2.0, 2.0)
    for i in eachindex(y)
        y[i] ~ Normal(θ * x[i], σ)
    end
end

# Register the model on startup
register_model("custom_model", custom_model, version="1.0.0")
EOF
```

2. **Mount the models directory** when running the container:
```bash
docker run -v $(pwd)/models:/app/models \
           -p 8080:8080 -p 8081:8081 \
           ghcr.io/pteradigm/rxinferkserve:latest
```

3. **Load models on startup** by setting environment variable:
```bash
docker run -v $(pwd)/models:/app/models \
           -e RXINFER_LOAD_MODELS="/app/models/*.jl" \
           -p 8080:8080 -p 8081:8081 \
           ghcr.io/pteradigm/rxinferkserve:latest
```

### Configuration Files

Mount configuration files for server settings:

```bash
docker run -v $(pwd)/config:/app/config \
           -v $(pwd)/models:/app/models \
           -e RXINFER_CONFIG="/app/config/server.toml" \
           ghcr.io/pteradigm/rxinferkserve:latest
```

### Persistent Storage

For production deployments with persistent model instances:

```bash
docker run -v rxinfer-data:/app/data \
           -v $(pwd)/models:/app/models \
           -v $(pwd)/logs:/app/logs \
           ghcr.io/pteradigm/rxinferkserve:latest
```

## Health Checks

The container includes health check configuration:

```bash
# Check container health
docker inspect --format='{{.State.Health.Status}}' container_name

# View health check logs
docker inspect --format='{{range .State.Health.Log}}{{.Output}}{{end}}' container_name
```

## Security Best Practices

1. **Run as non-root user** (already configured in Dockerfile)
2. **Use secrets for API keys**:
   ```bash
   docker secret create api_key ./api_key.txt
   docker service create --secret api_key rxinferkserve:latest
   ```

3. **Network isolation**:
   ```yaml
   networks:
     backend:
       driver: overlay
       encrypted: true
   ```

4. **Resource limits**:
   ```yaml
   deploy:
     resources:
       limits:
         cpus: '2'
         memory: 4G
   ```

## Monitoring

### Logs

```bash
# View logs
docker logs -f container_name

# JSON log parsing
docker logs container_name | jq '.level == "error"'
```

### Metrics

Export metrics for Prometheus:

```julia
# In your model code
using RxInferKServe.Metrics

@metric inference_duration_seconds "Time spent in inference" Histogram
@metric model_requests_total "Total requests per model" Counter [:model]
```

## Troubleshooting

### Slow Startup

If the container starts slowly:
1. Ensure system image is built during docker build
2. Increase memory allocation
3. Use volume mounts for precompiled code

### Connection Issues

```bash
# Test HTTP endpoint
docker exec container_name curl http://localhost:8080/v2/health/ready

# Test gRPC endpoint
docker exec container_name grpcurl -plaintext localhost:8081 inference.GRPCInferenceService/ServerReady
```

### Performance Tuning

```bash
# Run with Julia performance flags
docker run -e JULIA_NUM_THREADS=4 \
           -e JULIA_GC_THREADS=2 \
           ghcr.io/pteradigm/rxinferkserve:latest
```