# Base model definitions and inference execution

using RxInfer
using Distributions

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
        # Create the model with provided data
        model = model_fn(data)
        
        # Set up inference options
        inference_opts = merge(
            Dict(:iterations => iterations),
            options
        )
        
        # Run inference
        results = inference(
            model = model,
            data = data,
            iterations = get(inference_opts, :iterations, 10),
            returnvars = get(inference_opts, :returnvars, KeepLast()),
            free_energy = get(inference_opts, :free_energy, false)
        )
        
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
        
        # Extract free energy if available
        if hasfield(typeof(results), :free_energy)
            processed[:free_energy] = results.free_energy
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

# Example model definitions
function register_builtin_models()
    # Beta-Bernoulli model
    @model function beta_bernoulli(y)
        θ ~ Beta(1.0, 1.0)
        for i in 1:length(y)
            y[i] ~ Bernoulli(θ)
        end
    end
    
    register_model(
        "beta_bernoulli",
        beta_bernoulli,
        version="1.0.0",
        description="Beta-Bernoulli conjugate model for binary data"
    )
    
    # Linear regression model
    @model function linear_regression(x, y)
        α ~ Normal(0.0, 10.0)
        β ~ Normal(0.0, 10.0)
        σ ~ Gamma(1.0, 1.0)
        
        for i in 1:length(y)
            y[i] ~ Normal(α + β * x[i], σ)
        end
    end
    
    register_model(
        "linear_regression",
        linear_regression,
        version="1.0.0",
        description="Bayesian linear regression model"
    )
    
    # State space model
    @model function state_space_model(y, trend=0.0, process_noise=1.0, obs_noise=1.0)
        x = randomvar(length(y))
        
        x[1] ~ Normal(mean=0.0, variance=100.0)
        y[1] ~ Normal(mean=x[1], variance=obs_noise)
        
        for i in 2:length(y)
            x[i] ~ Normal(mean=x[i-1] + trend, variance=process_noise)
            y[i] ~ Normal(mean=x[i], variance=obs_noise)
        end
        
        return x
    end
    
    register_model(
        "state_space",
        state_space_model,
        version="1.0.0",
        description="Linear Gaussian state space model",
        parameters=Dict(
            "trend" => 0.0,
            "process_noise" => 1.0,
            "obs_noise" => 1.0
        )
    )
end