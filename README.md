# RxInferMLServer.jl

A Julia package for serving [RxInfer.jl](https://github.com/ReactiveBayes/RxInfer.jl) probabilistic models through REST APIs and MLServer integration.

## Features

- REST API for RxInfer.jl models with OpenAPI compliance
- MLServer custom runtime integration
- High-performance JSON serialization of probabilistic distributions
- Model lifecycle management with instance-based deployment
- Built-in authentication and CORS support
- Python and Julia client libraries
- Production-ready with PackageCompiler.jl support

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/rbellamy/RxInferMLServer.jl")
```

## Quick Start

### Starting the Server

```julia
using RxInferMLServer

# Start server with default configuration
start_server(host="0.0.0.0", port=8080)
```

### Using the Julia Client

```julia
using RxInferMLServer

# Create client
client = RxInferClient("http://localhost:8080/v1")

# List available models
models = list_models(client)

# Create model instance
instance = create_instance(client, "beta_bernoulli")

# Run inference
data = Dict("y" => [1, 0, 1, 1, 0, 1])
result = run_inference(client, instance["id"], data)
```

### Using the Python Client

```python
from rxinfer_client import RxInferClient

# Create client
client = RxInferClient("http://localhost:8080/v1")

# Create instance and run inference
instance = client.create_instance("beta_bernoulli")
result = client.infer(instance.id, {"y": [1, 0, 1, 1, 0, 1]})
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

- `GET /v1/health` - Health check
- `GET /v1/models` - List available models
- `GET /v1/models/instances` - List model instances
- `POST /v1/models/instances` - Create model instance
- `DELETE /v1/models/instances/{id}` - Delete instance
- `POST /v1/models/instances/{id}/infer` - Run inference

## Configuration

Server configuration options:

```julia
start_server(
    host="0.0.0.0",
    port=8080,
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
    ["RxInferMLServer", "RxInfer"],
    sysimage_path="rxinfer_server.so",
    precompile_execution_file="scripts/precompile.jl"
)
```

### Docker Deployment

See `docker/Dockerfile` for containerized deployment example.

## MLServer Integration

Use the provided runtime for MLServer:

```python
# model-settings.json
{
    "name": "rxinfer-model",
    "implementation": "rxinfer_mlserver.RxInferRuntime",
    "parameters": {
        "uri": "./models/my_model",
        "extra": {
            "model_name": "state_space"
        }
    }
}
```

## Development

### Running Tests

```julia
using Pkg
Pkg.test("RxInferMLServer")
```

### Building Documentation

```julia
using Pkg
Pkg.add("Documenter")
include("docs/make.jl")
```

## License

MIT License - see LICENSE file for details.