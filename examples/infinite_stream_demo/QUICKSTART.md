# Quick Start Guide - Infinite Data Stream Demo

## What This Demo Does

This demo implements an online learning system that processes streaming data using RxInfer.jl probabilistic models served via gRPC. It demonstrates:

- **Real-time Bayesian inference** on streaming data
- **Online parameter learning** with adaptive models
- **gRPC communication** using KServe v2 protocol
- **Containerized deployment** with Podman

## Prerequisites

- Podman installed with podman-compose
- 4GB+ RAM available
- Ports 8090 and 8091 available

## One-Command Start

From the project root:
```bash
make demo-stream
```

Or manually:
```bash
cd examples/infinite_stream_demo/docker
podman-compose up --build
```

Note: The `docker/` directory name is kept as a standard convention, but we use podman-compose with it.

## What Happens

1. **Julia Server Starts**: Registers three streaming models
   - Kalman filter for position tracking
   - Online AR parameter learning
   - Adaptive mixture model for regime detection

2. **Python Client Connects**: Generates synthetic streaming data
   - Sends data batches via gRPC
   - Receives inference results
   - Updates model states

3. **Continuous Processing**: Models adapt to changing data patterns
   - Kalman filter tracks moving objects
   - AR model learns time-varying parameters
   - Mixture model detects regime changes

## Monitoring Output

Watch the console for:
```
[Server] Streaming models registered successfully!
[Server] Server listening on:
[Server]   HTTP: http://0.0.0.0:8080 (mapped to host port 8090)
[Server]   gRPC: 0.0.0.0:8081 (mapped to host port 8091)

[Client] Server is live!
[Client] Model streaming_kalman is ready!
[Client] Processed 10 samples. Latest estimate: 1.234, Latest observation: 1.256
[Client] Processed 5 samples. Parameters: α=0.123, β=0.789
[Client] Processed 20 samples. Regime distribution: {0: 5, 1: 12, 2: 3}
```

## Stopping the Demo

Press `Ctrl+C` to gracefully shutdown both services.

## Customization

### Change Data Generation
Edit `client/streaming_client.py`:
- Modify `StreamingDataGenerator` methods
- Adjust batch sizes and intervals
- Change synthetic data parameters

### Add New Models
Edit `server/streaming_model.jl`:
- Define new `@model` functions
- Register in `start_streaming_server()`
- Add client inference calls

### Adjust Performance
Edit `docker-compose.yml` (used with podman-compose):
- `JULIA_NUM_THREADS`: Parallel processing
- Container resource limits
- Network timeouts

## Troubleshooting

If the demo fails:

1. **Check ports**: `lsof -i :8090,8091`
2. **View logs**: `podman-compose logs -f`
3. **Test server**: `curl http://localhost:8090/v2/health/live`
4. **Rebuild clean**: `podman-compose down && podman-compose build --no-cache`

## Next Steps

- Explore the [full README](README.md) for detailed documentation
- Modify models for your use case
- Connect real data sources
- Deploy to Kubernetes with the provided manifests