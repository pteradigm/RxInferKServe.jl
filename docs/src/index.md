# RxInferKServe.jl Documentation

Welcome to the documentation for RxInferKServe.jl, a Julia package that provides a KServe-compatible inference server for RxInfer.jl probabilistic models.

## Overview

RxInferKServe.jl enables you to:
- Serve RxInfer.jl probabilistic models through REST and gRPC APIs
- Deploy models using the KServe v2 inference protocol
- Scale inference workloads with Docker and Kubernetes
- Access models from Julia, Python, and other languages

## Features

- **KServe v2 Protocol**: Full compatibility with the KServe v2 inference protocol
- **Multiple Transports**: Support for both REST and gRPC APIs
- **Model Registry**: Dynamic model loading and instance management
- **Fast Startup**: System image compilation for sub-second startup times
- **Production Ready**: Health checks, structured logging, and metrics
- **Client Libraries**: Native Julia and Python client libraries

## Quick Start

```julia
using RxInferKServe
using RxInfer

# Define a model
@model function linear_regression(x, y)
    a ~ Normal(0, 10)
    b ~ Normal(0, 10)
    σ ~ Gamma(1, 1)
    
    for i in 1:length(y)
        y[i] ~ Normal(a * x[i] + b, σ)
    end
end

# Register the model
register_model("linear_regression", linear_regression, version="1.0.0")

# Start the server
start_server(host="0.0.0.0", port=8080)
```

## Documentation Contents

```@contents
Pages = ["getting-started.md", "api/models.md", "api/server.md", "api/client.md", "deployment/docker.md", "deployment/kubernetes.md", "examples.md"]
Depth = 2
```