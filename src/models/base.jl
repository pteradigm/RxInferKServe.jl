# Base model definitions and inference execution

using RxInfer
using Distributions

# Import datavar for creating data placeholders
import RxInfer: datavar, @initialization, NormalMeanVariance, GammaShapeScale, Beta

# Execute inference for a model instance
function infer(instance_id::UUID, data::Dict{Symbol,Any}; 
               iterations::Int=10, 
               options::Dict{Symbol,Any}=Dict{Symbol,Any}())
    
    # Get instance and model
    instance = get_model_instance(instance_id)
    model_def = get_model_definition(instance.model_name)
    model_fn = model_def["function"]
    
    # Prepare inference
    start_time = time()
    
    try
        # Get default parameters from model metadata
        default_params = model_def["metadata"].parameters
        
        # Convert default parameters keys to symbols
        default_params_symbols = Dict{Symbol,Any}(Symbol(k) => v for (k, v) in default_params)
        
        # Convert options keys to symbols and merge with defaults
        # Filter out inference-specific options that shouldn't be passed to the model
        inference_options = [:iterations, :returnvars, :free_energy]
        options_symbols = Dict{Symbol,Any}(
            Symbol(k) => v for (k, v) in options 
            if Symbol(k) ∉ inference_options
        )
        model_params = merge(default_params_symbols, options_symbols)
        
        # The key insight: we need to distinguish between:
        # 1. Observation variables (like y) that will be provided as data during inference
        # 2. Model parameters (like trend, process_noise) that are fixed when creating the model
        
        # For now, we'll use a simple heuristic: if it's in the data dict, it's an observation
        # Everything else (from model_params) is a hyperparameter
        
        # Build the arguments for model creation
        model_args = Dict{Symbol,Any}()
        
        # Add all model parameters
        for (k, v) in model_params
            model_args[k] = v
        end
        
        # For data variables, we don't add them to model_args
        # Instead, we'll pass the model and data separately to infer
        
        # Debug: print model arguments
        @debug "Model arguments (parameters only)" model_args
        @debug "Data for inference" data
        
        # Create the model generator by calling the model function
        # The @model macro creates a function that returns a ModelGenerator when called  
        # We need to determine the correct arguments for the model
        # Create the model generator by calling the function
        # The @model macro creates a function that returns a ModelGenerator when called
        # Call it without arguments - data will be passed separately to the infer function
        model = model_fn()
        
        # Data is passed separately to infer
        inference_data = data
        
        # Set up inference options
        inference_opts = merge(
            Dict(:iterations => iterations),
            options
        )
        
        # Get initialization for the model
        init_fn = get_model_initialization(instance.model_name)
        
        # Get initialization for the model
        init_fn = get_model_initialization(instance.model_name)
        
        # Check if we have empty data and provide appropriate defaults
        if isempty(inference_data)
            # For models that require data, we should error out with a clear message
            throw(ArgumentError("Model '$(instance.model_name)' requires input data but none was provided"))
        end
        
        # Run inference
        if !isnothing(init_fn)
            # Call the initialization function to get the actual initialization
            init = init_fn()
            results = RxInfer.infer(
                model = model,
                data = inference_data,
                iterations = get(inference_opts, :iterations, 10),
                returnvars = get(inference_opts, :returnvars, KeepLast()),
                free_energy = get(inference_opts, :free_energy, false),
                initialization = init
            )
        else
            results = RxInfer.infer(
                model = model,
                data = inference_data,
                iterations = get(inference_opts, :iterations, 10),
                returnvars = get(inference_opts, :returnvars, KeepLast()),
                free_energy = get(inference_opts, :free_energy, false)
            )
        end
        
        # Process results
        processed_results = process_inference_results(results)
        
        # Calculate duration
        duration_ms = (time() - start_time) * 1000
        
        # Update instance state if needed
        if haskey(processed_results, :state_update)
            merge!(instance.state, processed_results[:state_update])
            delete!(processed_results, :state_update)
        end
        
        @info "Inference completed" model=instance.model_name id=instance_id duration_ms=duration_ms
        
        return processed_results, duration_ms
        
    catch e
        @error "Inference failed" model=instance.model_name id=instance_id error=e
        rethrow(e)
    end
end

# Process RxInfer results into serializable format
function process_inference_results(results)
    processed = Dict{Symbol,Any}()
    
    # Handle different result types
    if results isa InferenceResult
        # Extract posteriors
        if hasfield(typeof(results), :posteriors)
            processed[:posteriors] = Dict{Symbol,Any}()
            for (var, posterior) in pairs(results.posteriors)
                processed[:posteriors][var] = posterior
            end
        end
        
        # Extract free energy if available and computed
        if hasfield(typeof(results), :free_energy)
            try
                fe = getfield(results, :free_energy)
                if !isnothing(fe)
                    processed[:free_energy] = fe
                end
            catch
                # Free energy wasn't computed, skip it
            end
        end
        
        # Extract other fields
        for field in fieldnames(typeof(results))
            if field ∉ [:posteriors, :free_energy]
                value = getfield(results, field)
                if !isnothing(value)
                    processed[field] = value
                end
            end
        end
    else
        # Handle raw results
        if results isa Dict
            processed = results
        else
            processed[:result] = results
        end
    end
    
    return processed
end

# Get model-specific initialization
function get_model_initialization(model_name::String)
    if model_name == "linear_regression"
        # Return a function that creates the initialization
        return () -> @initialization begin
            q(α) = NormalMeanVariance(0.0, 10.0)
            q(β) = NormalMeanVariance(0.0, 10.0) 
            q(σ) = GammaShapeScale(1.0, 1.0)
        end
    elseif model_name == "simple_gaussian"
        return () -> @initialization begin
            q(μ) = NormalMeanVariance(0.0, 10.0)
            q(σ) = GammaShapeScale(1.0, 1.0)
        end
    elseif model_name == "beta_bernoulli"
        return () -> @initialization begin
            q(θ) = Beta(1.0, 1.0)
        end
    else
        return nothing
    end
end

# Example model definitions

# Beta-Bernoulli model
@model function beta_bernoulli(y)
    θ ~ Beta(1.0, 1.0)
    for i in 1:length(y)
        y[i] ~ Bernoulli(θ)
    end
end

# Simple Gaussian model for testing
@model function simple_gaussian(y)
    μ ~ Normal(mean=0.0, variance=100.0)
    σ ~ Gamma(shape=1.0, scale=1.0)
    for i in 1:length(y)
        y[i] ~ Normal(mean=μ, variance=σ)
    end
end

# Linear regression model
@model function linear_regression(x, y)
    α ~ Normal(mean=0.0, variance=10.0)
    β ~ Normal(mean=0.0, variance=10.0)
    σ ~ Gamma(shape=1.0, scale=1.0)
    
    for i in 1:length(y)
        y[i] ~ Normal(mean=α + β * x[i], variance=σ)
    end
end

# State space model
@model function state_space_model(y, trend, process_noise, obs_noise)
    x = randomvar(length(y))
    
    x[1] ~ Normal(mean=0.0, variance=100.0)
    y[1] ~ Normal(mean=x[1], variance=obs_noise)
    
    for i in 2:length(y)
        x[i] ~ Normal(mean=x[i-1] + trend, variance=process_noise)
        y[i] ~ Normal(mean=x[i], variance=obs_noise)
    end
    
    return x
end

# Register built-in models
function register_builtin_models()
    register_model(
        "beta_bernoulli",
        beta_bernoulli,
        version="1.0.0",
        description="Beta-Bernoulli conjugate model for binary data",
        parameters=Dict{String,Any}(
            "inputs" => [
                Dict("name" => "y", "datatype" => "FP64", "shape" => [-1])
            ],
            "outputs" => [
                Dict("name" => "theta", "datatype" => "FP64", "shape" => [2])
            ]
        )
    )
    
    register_model(
        "simple_gaussian",
        simple_gaussian,
        version="1.0.0",
        description="Simple Gaussian model for single variable",
        parameters=Dict{String,Any}(
            "inputs" => [
                Dict("name" => "y", "datatype" => "FP64", "shape" => [-1])
            ],
            "outputs" => [
                Dict("name" => "mu", "datatype" => "FP64", "shape" => [1])
            ]
        )
    )
    
    register_model(
        "linear_regression",
        linear_regression,
        version="1.0.0",
        description="Bayesian linear regression model",
        parameters=Dict{String,Any}(
            "inputs" => [
                Dict("name" => "x", "datatype" => "FP64", "shape" => [-1]),
                Dict("name" => "y", "datatype" => "FP64", "shape" => [-1])
            ],
            "outputs" => [
                Dict("name" => "alpha", "datatype" => "FP64", "shape" => [1]),
                Dict("name" => "beta", "datatype" => "FP64", "shape" => [1])
            ]
        )
    )
    
    register_model(
        "state_space",
        state_space_model,
        version="1.0.0",
        description="Linear Gaussian state space model",
        parameters=Dict{String,Any}(
            "trend" => 0.0,
            "process_noise" => 1.0,
            "obs_noise" => 1.0,
            "inputs" => [
                Dict("name" => "y", "datatype" => "FP64", "shape" => [-1])
            ],
            "outputs" => [
                Dict("name" => "states", "datatype" => "FP64", "shape" => [-1])
            ]
        )
    )
end