"""
Basic usage example for RxInferKServe
"""

using RxInferKServe
using RxInfer

# Start the server in a separate task
server_task = @async start_server(port=8080, log_level="info")

# Wait a moment for server to start
sleep(2)

# Create a client
client = RxInferClient("http://localhost:8080/v1")

# Check server health
println("Server health check:")
health = health_check(client)
println("  Status: $(health.status)")
println("  Version: $(health.version)")
println()

# List available models
println("Available models:")
models = list_models(client)
for (name, metadata) in models
    println("  - $name (v$(metadata["version"])): $(metadata["description"])")
end
println()

# Example 1: Beta-Bernoulli model
println("Example 1: Beta-Bernoulli inference")
println("-" ^ 40)

# Create model instance
instance = create_instance(client, "beta_bernoulli")
println("Created instance: $(instance["id"])")

# Prepare data (coin flips: 1=heads, 0=tails)
coin_flips = [1, 0, 1, 1, 0, 1, 1, 1, 0, 1]
println("Observed coin flips: $coin_flips")
println("Observed heads: $(sum(coin_flips))/$(length(coin_flips))")

# Run inference
result = run_inference(client, instance["id"], Dict("y" => coin_flips))
println("Inference completed in $(result.duration_ms)ms")

# Extract posterior
posterior = result.results["posteriors"][:θ]
println("Posterior distribution: $(posterior["type"])")
println("  α = $(posterior["parameters"]["alpha"])")
println("  β = $(posterior["parameters"]["beta"])")

# Calculate posterior mean
posterior_mean = posterior["parameters"]["alpha"] / 
                (posterior["parameters"]["alpha"] + posterior["parameters"]["beta"])
println("Posterior mean: $posterior_mean")
println()

# Example 2: Linear regression
println("Example 2: Bayesian linear regression")
println("-" ^ 40)

# Create model instance
lr_instance = create_instance(client, "linear_regression")
println("Created instance: $(lr_instance["id"])")

# Generate synthetic data
n_points = 20
x_data = collect(1:n_points)
true_α = 2.0
true_β = 0.5
y_data = true_α .+ true_β .* x_data .+ 0.1 * randn(n_points)

println("Generated $n_points data points")
println("True parameters: α=$true_α, β=$true_β")

# Run inference
lr_result = run_inference(
    client, 
    lr_instance["id"], 
    Dict("x" => x_data, "y" => y_data),
    Dict("iterations" => 20)
)

println("Inference completed in $(lr_result.duration_ms)ms")

# Extract posteriors
α_post = lr_result.results["posteriors"][:α]
β_post = lr_result.results["posteriors"][:β]

println("Posterior for α: $(α_post["type"])")
println("  mean = $(α_post["parameters"]["mean"])")
println("  std = $(α_post["parameters"]["std"])")

println("Posterior for β: $(β_post["type"])")  
println("  mean = $(β_post["parameters"]["mean"])")
println("  std = $(β_post["parameters"]["std"])")
println()

# Example 3: State space model
println("Example 3: State space model")
println("-" ^ 40)

# Create model instance
ss_instance = create_instance(client, "state_space")
println("Created instance: $(ss_instance["id"])")

# Generate time series data
t = 1:50
true_trend = 0.1
true_state = cumsum(true_trend .+ 0.1 * randn(length(t)))
observations = true_state .+ 0.5 * randn(length(t))

println("Generated time series with $(length(t)) observations")

# Run inference with custom parameters
ss_result = run_inference(
    client,
    ss_instance["id"],
    Dict("y" => observations),
    Dict(
        "iterations" => 10,
        "trend" => 0.0,
        "process_noise" => 1.0,
        "obs_noise" => 1.0
    )
)

println("Inference completed in $(ss_result.duration_ms)ms")

if haskey(ss_result.results, :free_energy)
    println("Free energy: $(ss_result.results[:free_energy])")
end

# Clean up instances
println("\nCleaning up...")
delete_instance(client, instance["id"])
delete_instance(client, lr_instance["id"]) 
delete_instance(client, ss_instance["id"])

println("All instances deleted")

# List remaining instances
instances = list_instances(client)
println("Remaining instances: $(length(instances))")

# Shutdown server
println("\nShutting down server...")
stop_server()