# Client API

## Julia Client

### Creating a Client

```julia
using RxInferKServe.Client

# Basic client
client = RxInferClient("http://localhost:8080")

# With authentication
client = RxInferClient("http://localhost:8080", api_key="secret-key")

# With custom timeout
client = RxInferClient("http://localhost:8080", timeout=30)
```

### Server Operations

```julia
# Check server status
is_live = server_live(client)
is_ready = server_ready(client)

# Get server metadata
metadata = server_metadata(client)
```

### Model Operations

```julia
# List available models
models = list_models(client)

# Get model information
info = model_info(client, "model_name")

# Check model readiness
ready = model_ready(client, "model_name")
```

### Inference

```julia
# Simple inference with Julia data structures
data = Dict("x" => [1, 2, 3], "y" => [2.1, 4.2, 6.3])
result = infer(client, "linear_regression", data)

# Access results
posterior_mean = result["a"]["mean"]
posterior_var = result["a"]["variance"]
```

### Advanced Usage

```julia
# Create persistent model instance
instance_id = create_instance(client, "model_name")

# Run multiple inferences on same instance
for data in datasets
    result = infer_instance(client, instance_id, data)
    process_result(result)
end

# Clean up
delete_instance(client, instance_id)
```

## Python Client

### Installation

```bash
pip install rxinfer-client
```

### Basic Usage

```python
from rxinfer_client import RxInferClient

# Create client
client = RxInferClient("http://localhost:8080")

# Check server status
print(f"Server live: {client.server_live()}")
print(f"Server ready: {client.server_ready()}")

# List models
models = client.list_models()
for model in models:
    print(f"- {model['name']} v{model['version']}")
```

### Inference

```python
# Simple inference
data = {"x": [1, 2, 3], "y": [2.1, 4.2, 6.3]}
result = client.infer_simple("linear_regression", data)

# Access posteriors
print(f"Slope: {result['a']['mean']:.3f} ± {result['a']['variance']**0.5:.3f}")
print(f"Intercept: {result['b']['mean']:.3f} ± {result['b']['variance']**0.5:.3f}")
```

### KServe v2 Format

```python
# Full KServe v2 inference request
inputs = [
    {
        "name": "x",
        "shape": [3],
        "datatype": "FP64",
        "data": [1.0, 2.0, 3.0]
    },
    {
        "name": "y", 
        "shape": [3],
        "datatype": "FP64",
        "data": [2.1, 4.2, 6.3]
    }
]

response = client.infer("linear_regression", inputs)

# Parse outputs
for output in response["outputs"]:
    if output["name"] == "a":
        slope_mean = output["data"][0]
```

### Error Handling

```python
try:
    result = client.infer_simple("model_name", data)
except Exception as e:
    print(f"Inference failed: {e}")
```

## API Reference

### Julia Client

```@docs
RxInferClient
RxInferKServe.client_list_models
RxInferKServe.run_inference
```