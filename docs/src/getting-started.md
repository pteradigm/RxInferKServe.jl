# Getting Started

This guide will help you get up and running with RxInferKServe.jl.

## Installation

Add the package using Julia's package manager:

```julia
using Pkg
Pkg.add(url="https://github.com/pteradigm/RxInferKServe.jl")
```

## Basic Usage

### 1. Define a Model

First, define a probabilistic model using RxInfer.jl:

```julia
using RxInfer

@model function coin_flip(y)
    θ ~ Beta(2.0, 2.0)
    for i in eachindex(y)
        y[i] ~ Bernoulli(θ)
    end
end
```

### 2. Register the Model

Register your model with the server:

```julia
using RxInferKServe

register_model("coin_flip", coin_flip, 
    version="1.0.0",
    description="Simple coin flip model with Beta prior"
)
```

### 3. Start the Server

Start the inference server:

```julia
start_server(host="0.0.0.0", port=8080)
```

### 4. Make Inference Requests

#### Using the Julia Client

```julia
using RxInferKServe.Client

client = RxInferClient("http://localhost:8080")

# Run inference
data = Dict("y" => [1, 0, 1, 1, 0, 1, 0, 1])
result = infer(client, "coin_flip", data)

println("Posterior mean of θ: ", result["θ"]["mean"])
```

#### Using the Python Client

```python
from rxinfer_client import RxInferClient

client = RxInferClient("http://localhost:8080")

# Run inference
data = {"y": [1, 0, 1, 1, 0, 1, 0, 1]}
result = client.infer_simple("coin_flip", data)

print(f"Posterior mean of θ: {result['θ']['mean']}")
```

## Docker Deployment

For production deployments, use the provided Docker image:

```bash
docker run -p 8080:8080 -p 8081:8081 ghcr.io/pteradigm/rxinferkserve:latest
```

Or use docker-compose:

```bash
cd docker
docker-compose up
```

## Next Steps

- [Model Development](api/models.md) - Learn how to create and register models
- [Server Configuration](api/server.md) - Configure the server for your needs
- [Production Deployment](deployment/docker.md) - Deploy to production environments