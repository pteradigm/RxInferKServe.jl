# Infinite Data Stream Demo

This demo showcases RxInferKServe's capability to handle streaming data and perform online inference using RxInfer.jl models. The demo implements three different streaming inference scenarios:

1. **Kalman Filter**: Tracks a moving object with noisy observations
2. **Online AR Learning**: Learns time-varying parameters of an autoregressive process
3. **Adaptive Mixture Model**: Detects regime changes in streaming data

## Architecture

- **Server**: Julia-based RxInferKServe with custom streaming models
- **Client**: Python gRPC client that generates synthetic streaming data
- **Protocol**: KServe v2 inference protocol over gRPC
- **Orchestration**: Podman Compose

## Prerequisites

- Podman with podman-compose
- X11 display (for visualization) or modify to save plots to files
- Ports 8090 and 8091 available (demo uses different ports than main server)

## Quick Start

```bash
podman-compose up --build
```

## Manual Setup

### 1. Start the Julia Server

```bash
cd server
julia --project=../../.. streaming_model.jl
```

### 2. Generate Python Protobuf Files

```bash
cd client
./generate_proto.sh
```

### 3. Install Python Dependencies

```bash
cd client
pip install -r requirements.txt
```

### 4. Run the Streaming Client

```bash
cd client
python streaming_client.py
```

## Models

### Streaming Kalman Filter

Implements a Kalman filter for tracking position and velocity with unknown noise parameters:
- State: 2D (position, velocity)
- Observations: 1D (position only)
- Learns process and observation noise online

### Online AR Parameter Learning

Learns time-varying parameters of an AR(1) process:
- Parameters α and β evolve as random walks
- Uses sliding window for computational efficiency
- Adapts to parameter changes in real-time

### Adaptive Mixture Model

Detects regime changes using a Gaussian mixture model:
- Supports multiple regimes (default: 3)
- Updates mixture weights based on streaming data
- Identifies regime switches automatically

## Streaming Protocol

The demo uses the KServe v2 gRPC protocol with extensions for streaming:

1. **Batch Processing**: Data is sent in small batches for efficiency
2. **State Management**: Model state is preserved between batches
3. **Windowing**: Recent data is used for parameter updates
4. **Adaptive Learning**: Parameters adapt to data distribution changes

## Configuration

### Server Configuration

Edit `server/streaming_model.jl`:
- `port`: HTTP API port (default: 8080)
- `grpc_port`: gRPC API port (default: 8081)
- Model parameters in registration calls

### Client Configuration

Edit `client/streaming_client.py`:
- `batch_size`: Number of samples per batch
- `interval`: Time between batches (seconds)
- `window_size`: Sliding window size for AR model
- Generator parameters for synthetic data

## Visualization

The client provides real-time visualization of:
- Kalman filter: Observations vs filtered estimates
- AR process: Time series with parameter evolution
- Mixture model: Data colored by detected regime

To run without display (save to files instead):
```python
# Set in streaming_client.py
SAVE_PLOTS = True
PLOT_DIR = "results/plots"
```

## Extending the Demo

### Adding New Models

1. Define model in `server/streaming_model.jl`:
```julia
@model function my_streaming_model(data; params...)
    # Model definition
end
```

2. Register model in `start_streaming_server()`:
```julia
register_model(
    "my_model",
    my_streaming_model,
    version="1.0.0",
    description="My streaming model",
    parameters=Dict("supports_streaming" => true)
)
```

3. Add inference logic in client:
```python
results = self.client.streaming_inference(
    "my_model",
    {"data": batch},
    parameters={"param1": value1}
)
```

### Custom Data Generators

Add new data generation methods to `StreamingDataGenerator`:
```python
def generate_custom_data(self, n: int = 1) -> np.ndarray:
    # Generate your custom streaming data
    pass
```

## Troubleshooting

### gRPC Connection Issues
- Ensure server is running and healthy: `curl http://localhost:8080/v2/health/live`
- Check firewall settings for ports 8080 and 8081
- Verify network connectivity between containers

### Proto Generation Errors
- Install grpcio-tools: `pip install grpcio-tools`
- Check proto file path is correct
- Ensure write permissions in proto directory

### Visualization Issues
- For headless systems, set `MPLBACKEND=Agg`
- Use file output instead of display
- Check X11 forwarding for remote systems

## Performance Tuning

- Adjust batch sizes based on latency requirements
- Tune sliding window sizes for memory vs accuracy tradeoff  
- Use multiple Julia processes for parallel model execution
- Enable GPU support for large-scale inference