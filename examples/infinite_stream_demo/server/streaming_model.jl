"""
Infinite Data Stream Model for RxInferKServe

This implements an online learning model that processes streaming data
and updates its beliefs incrementally. The model learns the parameters
of a time-varying signal with drift.
"""

using RxInferKServe
using RxInfer
using Distributions

# Define the streaming inference model
@model function streaming_kalman_filter(
    y,
    Δt = 1.0;
    initial_state = nothing,
    initial_cov = nothing,
)
    # Model parameters
    # State transition: x[t] = A * x[t-1] + w[t]
    # Observation: y[t] = H * x[t] + v[t]

    # Process noise covariance
    Q ~ Wishart(2, [0.01 0.0; 0.0 0.001])

    # Observation noise variance
    R ~ Gamma(2.0, 0.5)

    # State transition matrix (position and velocity)
    A = [1.0 Δt; 0.0 1.0]

    # Observation matrix (observe position only)
    H = [1.0 0.0]

    n = length(y)

    # Hidden states
    x = randomvar(n)

    # Initial state
    if initial_state === nothing
        x[1] ~ MvNormal([0.0, 0.0], [1.0 0.0; 0.0 0.1])
    else
        x[1] ~ MvNormal(initial_state, initial_cov)
    end

    # State transitions and observations
    for t = 2:n
        x[t] ~ MvNormal(A * x[t-1], Q)
        y[t-1] ~ Normal(dot(H, x[t-1]), sqrt(R))
    end

    # Last observation
    y[n] ~ Normal(dot(H, x[n]), sqrt(R))

    return x, Q, R
end

# Online learning model for parameter estimation
@model function online_parameter_learning(y, x_prev = nothing; window_size = 20)
    # This model learns parameters of a AR(1) process with time-varying coefficients
    # y[t] = α[t] + β[t] * y[t-1] + ε[t]

    # Hyperparameters for parameter evolution
    τ_α ~ Gamma(2.0, 0.1)  # Precision for α drift
    τ_β ~ Gamma(2.0, 0.1)  # Precision for β drift
    τ_obs ~ Gamma(2.0, 1.0)  # Observation precision

    n = length(y)

    # Time-varying parameters
    α = randomvar(n)
    β = randomvar(n)

    # Initial parameters
    α[1] ~ Normal(0.0, 1.0)
    β[1] ~ Normal(0.8, 0.2)  # Slight persistence expected

    # Parameter evolution and observations
    for t = 2:n
        # Random walk for parameters
        α[t] ~ Normal(α[t-1], 1/sqrt(τ_α))
        β[t] ~ Normal(β[t-1], 1/sqrt(τ_β))

        # Observation model
        if x_prev !== nothing && t <= length(x_prev) + 1
            y_prev = t > 1 ? (t <= length(x_prev) ? x_prev[t-1] : y[1]) : 0.0
        else
            y_prev = t > 1 ? y[t-1] : 0.0
        end

        y[t] ~ Normal(α[t] + β[t] * y_prev, 1/sqrt(τ_obs))
    end

    # First observation (when no previous data)
    if x_prev === nothing || length(x_prev) == 0
        y[1] ~ Normal(α[1], 1/sqrt(τ_obs))
    else
        y[1] ~ Normal(α[1] + β[1] * x_prev[end], 1/sqrt(τ_obs))
    end

    return α, β, τ_α, τ_β, τ_obs
end

# Adaptive mixture model for detecting regime changes
@model function adaptive_mixture_model(y; n_components = 3, previous_weights = nothing)
    n = length(y)

    # Mixture weights with potential memory from previous batch
    if previous_weights === nothing
        π ~ Dirichlet(ones(n_components))
    else
        # Use previous weights as prior
        π ~ Dirichlet(previous_weights * 10.0)  # Stronger prior based on history
    end

    # Component parameters
    μ = randomvar(n_components)
    σ = randomvar(n_components)

    for k = 1:n_components
        μ[k] ~ Normal(0.0, 10.0)
        σ[k] ~ Gamma(2.0, 1.0)
    end

    # Latent assignments
    z = randomvar(n)

    # Observations
    for i = 1:n
        z[i] ~ Categorical(π)
        y[i] ~ Normal(μ[z[i]], σ[z[i]])
    end

    return z, μ, σ, π
end

# Function to start the streaming server
function start_streaming_server(; port = 8080, grpc_port = 8081)
    println("Starting RxInferKServe with streaming models...")

    # Start server
    server = start_server(
        host = "0.0.0.0",
        port = port,
        grpc_port = grpc_port,
        enable_grpc = true,
        log_level = "info",
    )

    # Register streaming models
    register_model(
        "streaming_kalman",
        streaming_kalman_filter,
        version = "1.0.0",
        description = "Kalman filter for streaming data with unknown noise parameters",
        parameters = Dict("supports_streaming" => true, "state_dims" => 2, "obs_dims" => 1),
    )

    register_model(
        "online_ar_learning",
        online_parameter_learning,
        version = "1.0.0",
        description = "Online learning of time-varying AR(1) parameters",
        parameters = Dict(
            "supports_streaming" => true,
            "window_size" => 20,
            "ar_order" => 1,
        ),
    )

    register_model(
        "adaptive_mixture",
        adaptive_mixture_model,
        version = "1.0.0",
        description = "Adaptive mixture model for regime detection",
        parameters = Dict(
            "supports_streaming" => true,
            "n_components" => 3,
            "adaptive" => true,
        ),
    )

    println("Streaming models registered successfully!")
    println("Server listening on:")
    println("  HTTP: http://0.0.0.0:$port")
    println("  gRPC: 0.0.0.0:$grpc_port")

    return server
end

# Main execution
if abspath(PROGRAM_FILE) == @__FILE__
    server = start_streaming_server()

    println("\nServer is ready for streaming inference!")
    println("Press Ctrl+C to stop...")

    try
        wait(server)
    catch e
        if e isa InterruptException
            println("\nShutting down server...")
            stop_server()
        else
            rethrow(e)
        end
    end
end
