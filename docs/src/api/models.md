# Model API

## Model Registration

### Basic Registration

```julia
register_model(name::String, model_fn::Function; kwargs...)
```

Register a RxInfer model for serving.

**Arguments:**
- `name`: Unique identifier for the model
- `model_fn`: RxInfer model function created with `@model`

**Keyword Arguments:**
- `version`: Model version (default: "1.0.0")
- `description`: Human-readable description
- `metadata`: Additional metadata dictionary

**Example:**
```julia
@model function linear_regression(x, y)
    a ~ Normal(0, 10)
    b ~ Normal(0, 10)
    σ ~ Gamma(1, 1)
    
    for i in eachindex(y)
        y[i] ~ Normal(a * x[i] + b, σ)
    end
end

register_model("linear_regression", linear_regression,
    version="2.0.0",
    description="Bayesian linear regression with normal priors"
)
```

### Model Lifecycle

Models can exist in different states:
- **Registered**: Model is available for creating instances
- **Ready**: Model instance is ready to serve requests
- **Failed**: Model instance encountered an error

## Model Instances

Each inference request can create a new model instance or reuse existing ones:

```julia
# Client automatically manages instances
result = infer(client, "model_name", data)

# Or manually create an instance
instance_id = create_instance(client, "model_name")
result = infer_instance(client, instance_id, data)
delete_instance(client, instance_id)
```

## Model Metadata

Query model information:

```julia
# Get model info
info = model_info(client, "model_name")
println("Version: ", info["version"])
println("Description: ", info["description"])

# List all models
models = list_models(client)
for model in models
    println("- ", model["name"], " (", model["version"], ")")
end
```

## Inference Results

Inference results include:
- **Posteriors**: Posterior distributions for all latent variables
- **Statistics**: Mean, variance, and other moments
- **Diagnostics**: Convergence information and warnings

Example result structure:
```julia
{
    "θ": {
        "mean": 0.65,
        "variance": 0.023,
        "distribution": "Beta",
        "parameters": {"a": 10.0, "b": 5.4}
    },
    "diagnostics": {
        "converged": true,
        "iterations": 10,
        "free_energy": -15.3
    }
}
```

## API Reference

```@docs
RxInferKServe.register_model
RxInferKServe.unregister_model
RxInferKServe.get_model
RxInferKServe.list_registered_models
```