"""
Example of registering and using custom RxInfer models
"""

using RxInferKServe
using RxInfer
using Distributions

# Define a custom hierarchical model
@model function hierarchical_gaussian(group_data)
    # Hyperpriors
    μ_global ~ Normal(0.0, 10.0)
    σ_global ~ Gamma(2.0, 2.0)
    σ_groups ~ Gamma(2.0, 2.0)

    n_groups = length(group_data)

    # Group-level parameters
    μ_group = randomvar(n_groups)
    for g = 1:n_groups
        μ_group[g] ~ Normal(μ_global, σ_global)
    end

    # Observations
    for g = 1:n_groups
        n_obs = length(group_data[g])
        for i = 1:n_obs
            group_data[g][i] ~ Normal(μ_group[g], σ_groups)
        end
    end

    return μ_group, μ_global, σ_global, σ_groups
end

# Define a time-varying parameter model
@model function time_varying_regression(x, y, change_points)
    n = length(y)
    n_segments = length(change_points) + 1

    # Parameters for each segment
    α = randomvar(n_segments)
    β = randomvar(n_segments)
    σ = randomvar(n_segments)

    # Priors for each segment
    for s = 1:n_segments
        α[s] ~ Normal(0.0, 10.0)
        β[s] ~ Normal(0.0, 10.0)
        σ[s] ~ Gamma(2.0, 2.0)
    end

    # Observations
    segment_idx = 1
    for i = 1:n
        # Check if we've passed a change point
        if segment_idx < n_segments && i > change_points[segment_idx]
            segment_idx += 1
        end

        # Use parameters for current segment
        y[i] ~ Normal(α[segment_idx] + β[segment_idx] * x[i], σ[segment_idx])
    end

    return α, β, σ
end

# Define a mixture model
@model function gaussian_mixture(y, n_components = 2)
    n = length(y)

    # Mixture weights
    π ~ Dirichlet(ones(n_components))

    # Component parameters
    μ = randomvar(n_components)
    σ = randomvar(n_components)

    for k = 1:n_components
        μ[k] ~ Normal(0.0, 10.0)
        σ[k] ~ Gamma(2.0, 2.0)
    end

    # Latent cluster assignments
    z = randomvar(n)

    # Observations
    for i = 1:n
        z[i] ~ Categorical(π)
        y[i] ~ Normal(μ[z[i]], σ[z[i]])
    end

    return z, μ, σ, π
end

# Start server and register models
println("Starting server and registering custom models...")

server_task = @async start_server(port = 8080)
sleep(2)

# Register custom models
register_model(
    "hierarchical_gaussian",
    hierarchical_gaussian,
    version = "1.0.0",
    description = "Hierarchical Gaussian model for grouped data",
)

register_model(
    "time_varying_regression",
    time_varying_regression,
    version = "1.0.0",
    description = "Regression model with time-varying parameters",
)

register_model(
    "gaussian_mixture",
    gaussian_mixture,
    version = "1.0.0",
    description = "Gaussian mixture model for clustering",
)

# Create client
client = RxInferClient("http://localhost:8080/v1")

# Example 1: Hierarchical model
println("\nExample 1: Hierarchical Gaussian Model")
println("-" ^ 50)

# Generate grouped data
n_groups = 3
group_means = [2.0, 5.0, 8.0]
group_data = []

for g = 1:n_groups
    n_obs = 20
    data = group_means[g] .+ 0.5 * randn(n_obs)
    push!(group_data, data)
end

println("Generated data for $n_groups groups")
for g = 1:n_groups
    println(
        "  Group $g: mean = $(round(mean(group_data[g]), digits=2)), n = $(length(group_data[g]))",
    )
end

# Create instance and run inference
h_instance = create_instance(client, "hierarchical_gaussian")
h_result = run_inference(
    client,
    h_instance["id"],
    Dict("group_data" => group_data),
    Dict("iterations" => 20),
)

println("Inference completed in $(h_result.duration_ms)ms")

# Extract global parameters
μ_global_post = h_result.results["posteriors"][:μ_global]
println(
    "Global mean posterior: μ = $(round(μ_global_post["parameters"]["mean"], digits=2))",
)

# Example 2: Time-varying regression
println("\nExample 2: Time-Varying Regression")
println("-" ^ 50)

# Generate data with change points
n = 100
x = collect(1:n) / 10
change_points = [40, 70]

# Different parameters for each segment
true_params = [(α = 1.0, β = 0.5), (α = 3.0, β = -0.2), (α = 0.0, β = 0.8)]

y = zeros(n)
segment_idx = 1
for i = 1:n
    if segment_idx < length(true_params) && i > change_points[segment_idx]
        segment_idx += 1
    end
    y[i] = true_params[segment_idx].α + true_params[segment_idx].β * x[i] + 0.3 * randn()
end

println("Generated data with change points at: $change_points")

# Create instance and run inference
tv_instance = create_instance(client, "time_varying_regression")
tv_result = run_inference(
    client,
    tv_instance["id"],
    Dict("x" => x, "y" => y, "change_points" => change_points),
    Dict("iterations" => 20),
)

println("Inference completed in $(tv_result.duration_ms)ms")

# Extract segment parameters
α_posts = h_result.results["posteriors"][:α]
println("Detected $(length(α_posts)) segments")

# Example 3: Gaussian mixture
println("\nExample 3: Gaussian Mixture Model")
println("-" ^ 50)

# Generate mixture data
n_samples = 150
true_means = [-2.0, 3.0]
true_stds = [0.8, 1.2]
true_weights = [0.3, 0.7]

# Sample from mixture
using StatsBase
mixture_data = Float64[]
for i = 1:n_samples
    component = sample(1:2, Weights(true_weights))
    push!(mixture_data, true_means[component] + true_stds[component] * randn())
end

println("Generated mixture data with $(length(true_means)) components")

# Create instance and run inference
gm_instance = create_instance(client, "gaussian_mixture")
gm_result = run_inference(
    client,
    gm_instance["id"],
    Dict("y" => mixture_data, "n_components" => 2),
    Dict("iterations" => 30),
)

println("Inference completed in $(gm_result.duration_ms)ms")

# Clean up
println("\nCleaning up...")
delete_instance(client, h_instance["id"])
delete_instance(client, tv_instance["id"])
delete_instance(client, gm_instance["id"])

stop_server()
println("Done!")
