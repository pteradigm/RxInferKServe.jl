# RxInferKServe.jl

A Julia package for serving [RxInfer.jl](https://github.com/ReactiveBayes/RxInfer.jl) probabilistic models through KServe v2 inference protocol with both HTTP REST and gRPC endpoints.

## Features

- Full KServe v2 inference protocol implementation
- Both HTTP REST and gRPC endpoints
- MLServer/KServe compatible runtime
- High-performance JSON serialization of probabilistic distributions
- Model lifecycle management with instance-based deployment
- Built-in authentication and CORS support
- Python and Julia client libraries
- Production-ready with PackageCompiler.jl support

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/rbellamy/RxInferKServe.jl")
```

## Quick Start

### Starting the Server

```julia
using RxInferKServe

# Start server with default configuration
start_server(host="0.0.0.0", port=8080, grpc_port=8081)
```

### Using the Julia Client

```julia
using RxInferKServe.Client

# Create client
client = RxInferClient("http://localhost:8080")

# List available models
models = list_models(client)

# Get model metadata
info = model_info(client, "beta_bernoulli")

# Run inference directly
data = Dict("y" => [1, 0, 1, 1, 0, 1])
result = infer(client, "beta_bernoulli", data)
```

### Using the Python Client

```python
from rxinfer_client import RxInferClient

# Create client
client = RxInferClient("http://localhost:8080")

# Check server status
live = client.server_live()
ready = client.server_ready()

# List models
models = client.list_models()

# Get model metadata
metadata = client.model_metadata("beta_bernoulli")

# Run inference (simple method)
result = client.infer_simple("beta_bernoulli", {"y": [1, 0, 1, 1, 0, 1]})

# Or use full KServe v2 format
inputs = [{
    "name": "y",
    "datatype": "FP64",
    "shape": [6],
    "data": [1.0, 0.0, 1.0, 1.0, 0.0, 1.0]
}]
result = client.infer("beta_bernoulli", inputs)
```

## Model Registration

Register custom RxInfer models:

```julia
using RxInfer

@model function custom_model(x, y)
    # Model definition
    θ ~ Beta(1.0, 1.0)
    for i in 1:length(y)
        y[i] ~ Normal(θ * x[i], 1.0)
    end
end

register_model("custom_model", custom_model, 
    version="1.0.0",
    description="Custom regression model"
)
```

## API Endpoints

### HTTP REST (KServe v2)
- `GET /v2/health/live` - Server liveness check
- `GET /v2/health/ready` - Server readiness check  
- `GET /v2/models` - List available models
- `GET /v2/models/{model_name}` - Get model metadata
- `GET /v2/models/{model_name}/ready` - Check model readiness
- `POST /v2/models/{model_name}/infer` - Run inference

### gRPC Services
- `ServerLive` - Server liveness check
- `ServerReady` - Server readiness check
- `ModelReady` - Model readiness check
- `ServerMetadata` - Server metadata
- `ModelMetadata` - Model metadata  
- `ModelInfer` - Run inference

## Configuration

Server configuration options:

```julia
start_server(
    host="0.0.0.0",
    port=8080,
    grpc_port=8081,
    enable_grpc=true,
    workers=4,
    enable_auth=true,
    api_keys=["secret-key-1", "secret-key-2"],
    enable_cors=true,
    log_level="info"
)
```

## Production Deployment

### Using PackageCompiler

Create a precompiled system image for fast startup:

```julia
using PackageCompiler

create_sysimage(
    ["RxInferKServe", "RxInfer"],
    sysimage_path="rxinfer_server.so",
    precompile_execution_file="scripts/precompile.jl"
)
```

### Docker Deployment

See `docker/Dockerfile` for containerized deployment example.

## Protocol Implementation

### KServe v2 Protocol

RxInferKServe implements the official KServe v2 inference protocol with full gRPC and HTTP REST compatibility:

- **Protobuf Definitions**: Located in `proto/kserve/v2/inference.proto` following official KServe v2 specification
- **Generated Code**: Protobuf files generated into `src/grpc/` using ProtoBuf.jl
- **Build System**: Use `make proto` to regenerate protobuf files after schema changes

### KServe/MLServer Integration

The server is fully compatible with KServe and MLServer deployments:

```yaml
# KServe InferenceService
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: rxinfer-model
spec:
  predictor:
    containers:
    - name: rxinfer-container
      image: rxinfer-mlserver:latest
      ports:
      - containerPort: 8080
        protocol: TCP
      - containerPort: 8081
        protocol: TCP
      env:
      - name: MODEL_NAME
        value: "linear_regression"
```

## Development

### Build System

The project includes a comprehensive Makefile for development tasks:

```bash
# Install dependencies and build
make all

# Build system image for fast startup
make sysimage

# Generate protobuf files from proto definitions
make proto

# Run tests
make test

# Start development server
make server-dev

# See all available targets
make help
```

### Running Tests

```julia
using Pkg
Pkg.test("RxInferKServe")
```

Or using Make:

```bash
make test
```

### Building Documentation

```julia
using Pkg
Pkg.add("Documenter")
include("docs/make.jl")
```

## License

MIT License - see LICENSE file for details.