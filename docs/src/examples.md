# Examples

## Basic Examples

### Beta-Bernoulli Model

A simple coin-flipping model with unknown bias:

```julia
using RxInfer, RxInferKServe

@model function coin_flip(y)
    # Prior belief about coin bias
    θ ~ Beta(2.0, 2.0)
    
    # Likelihood of observations
    for i in eachindex(y)
        y[i] ~ Bernoulli(θ)
    end
end

# Register and start server
register_model("coin_flip", coin_flip)
start_server()

# Client usage
using RxInferKServe.Client
client = RxInferClient("http://localhost:8080")

# Observed coin flips: 7 heads, 3 tails
data = Dict("y" => [1, 1, 0, 1, 1, 0, 1, 1, 0, 1])
result = infer(client, "coin_flip", data)

println("Posterior probability of heads: $(result["θ"]["mean"])")
# Output: Posterior probability of heads: 0.666...
```

### Linear Regression

Bayesian linear regression with uncertainty quantification:

```julia
@model function linear_regression(x, y)
    # Priors
    slope ~ Normal(0, 10)
    intercept ~ Normal(0, 10)
    noise ~ Gamma(1, 1)
    
    # Likelihood
    for i in eachindex(y)
        y[i] ~ Normal(slope * x[i] + intercept, noise)
    end
end

register_model("linear_regression", linear_regression)

# Generate synthetic data
x = collect(1:10)
y_true = 2 .* x .+ 3
y_observed = y_true .+ randn(10) * 0.5

# Run inference
data = Dict("x" => x, "y" => y_observed)
result = infer(client, "linear_regression", data)

println("Slope: $(result["slope"]["mean"]) ± $(sqrt(result["slope"]["variance"]))")
println("Intercept: $(result["intercept"]["mean"]) ± $(sqrt(result["intercept"]["variance"]))")
```

## Advanced Examples

### Hierarchical Model

Group-level effects with partial pooling:

```julia
@model function hierarchical_model(group, y)
    # Hyperpriors
    μ_global ~ Normal(0, 10)
    σ_global ~ Gamma(2, 2)
    σ_group ~ Gamma(2, 2)
    
    # Group-level parameters
    n_groups = maximum(group)
    μ_group = Vector{Float64}(undef, n_groups)
    for g in 1:n_groups
        μ_group[g] ~ Normal(μ_global, σ_global)
    end
    
    # Observations
    for i in eachindex(y)
        y[i] ~ Normal(μ_group[group[i]], σ_group)
    end
end

register_model("hierarchical", hierarchical_model)

# Data from 3 groups
group_ids = [1, 1, 1, 2, 2, 2, 3, 3, 3]
observations = [5.1, 4.9, 5.2, 7.1, 6.8, 7.3, 3.2, 3.1, 2.9]

data = Dict("group" => group_ids, "y" => observations)
result = infer(client, "hierarchical", data)
```

### Time Series Model

Autoregressive model for time series:

```julia
@model function ar1_model(y)
    # Parameters
    α ~ Normal(0, 1)  # AR coefficient
    σ ~ Gamma(2, 2)   # Innovation variance
    μ ~ Normal(0, 10) # Mean level
    
    # Initial observation
    y[1] ~ Normal(μ, σ)
    
    # Subsequent observations
    for t in 2:length(y)
        y[t] ~ Normal(μ + α * (y[t-1] - μ), σ)
    end
end

register_model("ar1", ar1_model)

# Simulate AR(1) process
T = 100
α_true = 0.7
μ_true = 5.0
σ_true = 0.5

y = zeros(T)
y[1] = μ_true + randn() * σ_true
for t in 2:T
    y[t] = μ_true + α_true * (y[t-1] - μ_true) + randn() * σ_true
end

# Inference
result = infer(client, "ar1", Dict("y" => y))
println("AR coefficient: $(result["α"]["mean"]) (true: $α_true)")
```

### Mixture Model

Gaussian mixture for clustering:

```julia
@model function gaussian_mixture(y, K=2)
    # Mixture weights
    π ~ Dirichlet(K, 1.0)
    
    # Component parameters
    μ = Vector{Float64}(undef, K)
    σ = Vector{Float64}(undef, K)
    for k in 1:K
        μ[k] ~ Normal(0, 10)
        σ[k] ~ Gamma(2, 2)
    end
    
    # Observations
    for i in eachindex(y)
        y[i] ~ Mixture(Normal.(μ, σ), π)
    end
end

register_model("gmm", gaussian_mixture)

# Generate mixture data
n1, n2 = 50, 50
data1 = randn(n1) .+ (-2)
data2 = randn(n2) .+ 3
y_mixed = vcat(data1, data2)
shuffle!(y_mixed)

# Inference with K=2 components
result = infer(client, "gmm", Dict("y" => y_mixed, "K" => 2))
```

## Integration Examples

### With DataFrames

```julia
using DataFrames, CSV

# Load data
df = CSV.read("data.csv", DataFrame)

# Prepare for inference
data = Dict(
    "x" => df.feature1,
    "y" => df.target
)

# Run inference
result = infer(client, "my_model", data)

# Store results
df.prediction = result["prediction"]["mean"]
df.uncertainty = sqrt.(result["prediction"]["variance"])
```

### Batch Processing

```julia
# Process multiple datasets
datasets = [load_dataset(i) for i in 1:10]

# Parallel inference using model instances
using Distributed
@everywhere using RxInferKServe.Client

results = pmap(datasets) do data
    client = RxInferClient("http://localhost:8080")
    infer(client, "model_name", data)
end
```

### Real-time Inference

```julia
using HTTP

# Create inference endpoint
HTTP.serve("0.0.0.0", 8000) do request
    # Parse incoming data
    data = JSON3.read(request.body)
    
    # Run inference
    result = infer(client, "model_name", data)
    
    # Return prediction
    return HTTP.Response(200, JSON3.write(result))
end
```

## Performance Optimization

### Using System Images

```julia
# Build optimized system image
using PackageCompiler

create_sysimage(
    ["RxInferKServe", "RxInfer"],
    sysimage_path="inference_server.so",
    precompile_execution_file="precompile_script.jl"
)

# Start server with system image
# julia --sysimage=inference_server.so server.jl
```

### Model Caching

```julia
# Keep model instances warm
instance_cache = Dict{String, String}()

function get_or_create_instance(client, model_name)
    if !haskey(instance_cache, model_name)
        instance_cache[model_name] = create_instance(client, model_name)
    end
    return instance_cache[model_name]
end

# Use cached instance
instance_id = get_or_create_instance(client, "expensive_model")
result = infer_instance(client, instance_id, data)
```