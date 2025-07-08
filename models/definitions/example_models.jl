"""
Example model definitions for RxInferKServe
"""

using RxInfer
using Distributions

# Kalman Filter for 1D tracking
@model function kalman_filter(y, Q=1.0, R=1.0)
    n = length(y)
    x = randomvar(n)
    
    # Initial state
    x[1] ~ Normal(0.0, 100.0)
    y[1] ~ Normal(x[1], R)
    
    # State transitions
    for t in 2:n
        x[t] ~ Normal(x[t-1], Q)
        y[t] ~ Normal(x[t], R)
    end
    
    return x
end

# Autoregressive model
@model function ar_model(y, order=2)
    n = length(y)
    
    # AR coefficients
    φ = randomvar(order)
    for i in 1:order
        φ[i] ~ Normal(0.0, 1.0)
    end
    
    # Noise variance
    σ ~ Gamma(2.0, 2.0)
    
    # Initial observations
    for t in 1:order
        y[t] ~ Normal(0.0, σ)
    end
    
    # AR process
    for t in (order+1):n
        mean_t = sum(φ[i] * y[t-i] for i in 1:order)
        y[t] ~ Normal(mean_t, σ)
    end
    
    return φ, σ
end

# Hidden Markov Model
@model function hmm_gaussian(y, n_states=2)
    n = length(y)
    
    # Transition matrix (simplified - using symmetric Dirichlet)
    A = randomvar((n_states, n_states))
    for i in 1:n_states
        A[i, :] ~ Dirichlet(ones(n_states))
    end
    
    # Initial state distribution
    π ~ Dirichlet(ones(n_states))
    
    # Emission parameters
    μ = randomvar(n_states)
    σ = randomvar(n_states)
    
    for k in 1:n_states
        μ[k] ~ Normal(0.0, 10.0)
        σ[k] ~ Gamma(2.0, 2.0)
    end
    
    # Hidden states
    z = randomvar(n)
    
    # Initial state
    z[1] ~ Categorical(π)
    y[1] ~ Normal(μ[z[1]], σ[z[1]])
    
    # State transitions and emissions
    for t in 2:n
        z[t] ~ Categorical(A[z[t-1], :])
        y[t] ~ Normal(μ[z[t]], σ[z[t]])
    end
    
    return z, μ, σ, A, π
end

# Bayesian Neural Network (simple 1-hidden layer)
@model function bnn_regression(X, y, n_hidden=10)
    n_features = size(X, 2)
    n_samples = size(X, 1)
    
    # First layer weights and biases
    W1 = randomvar((n_features, n_hidden))
    b1 = randomvar(n_hidden)
    
    for i in 1:n_features, j in 1:n_hidden
        W1[i,j] ~ Normal(0.0, 1.0)
    end
    
    for j in 1:n_hidden
        b1[j] ~ Normal(0.0, 1.0)
    end
    
    # Second layer weights and bias
    W2 = randomvar(n_hidden)
    b2 ~ Normal(0.0, 1.0)
    
    for j in 1:n_hidden
        W2[j] ~ Normal(0.0, 1.0)
    end
    
    # Observation noise
    σ ~ Gamma(2.0, 2.0)
    
    # Forward pass with tanh activation
    for i in 1:n_samples
        hidden = tanh.(X[i,:] * W1 .+ b1')
        μ_i = dot(hidden, W2) + b2
        y[i] ~ Normal(μ_i, σ)
    end
    
    return W1, b1, W2, b2, σ
end

# Export function to register all models
function register_example_models()
    register_model(
        "kalman_filter",
        kalman_filter,
        version="1.0.0",
        description="1D Kalman filter for tracking",
        parameters=Dict("Q" => 1.0, "R" => 1.0)
    )
    
    register_model(
        "ar_model", 
        ar_model,
        version="1.0.0",
        description="Autoregressive model of specified order",
        parameters=Dict("order" => 2)
    )
    
    register_model(
        "hmm_gaussian",
        hmm_gaussian,
        version="1.0.0",
        description="Hidden Markov Model with Gaussian emissions",
        parameters=Dict("n_states" => 2)
    )
    
    register_model(
        "bnn_regression",
        bnn_regression,
        version="1.0.0",
        description="Bayesian Neural Network for regression",
        parameters=Dict("n_hidden" => 10)
    )
end