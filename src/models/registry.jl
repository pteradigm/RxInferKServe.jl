# Model registry for managing RxInfer models

using UUIDs
using Dates
using Base.Threads

"""
    ModelRegistry

Registry for managing RxInfer models and their instances.

# Fields
- `models::Dict{String,Any}`: Maps model names to their definitions
- `instances::Dict{UUID,ModelInstance}`: Maps instance IDs to model instances
- `lock::ReentrantLock`: Thread-safe access control

# Description
The ModelRegistry provides centralized management of probabilistic models,
allowing registration, instantiation, and lifecycle management of RxInfer models.

# Example
```julia
# Access the global registry
registry = RxInferKServe.GLOBAL_REGISTRY

# Register a model
register_model("my_model", my_model_function)

# List registered models
models = list_registered_models()
```
"""
mutable struct ModelRegistry
    models::Dict{String,Any}  # Model name -> model definition
    instances::Dict{UUID,ModelInstance}  # Instance ID -> instance
    lock::ReentrantLock
end

# Global registry instance
const GLOBAL_REGISTRY =
    ModelRegistry(Dict{String,Any}(), Dict{UUID,ModelInstance}(), ReentrantLock())

"""
    register_model(name::String, model_fn::Function; version="1.0.0", description="", parameters=Dict())

Register a new RxInfer model in the global registry.

# Arguments
- `name::String`: Unique name for the model
- `model_fn::Function`: The @model function from RxInfer
- `version::String="1.0.0"`: Model version
- `description::String=""`: Human-readable description
- `parameters::Dict{String,Any}=Dict()`: Default model parameters and metadata

# Example
```julia
@model function my_model(x, y)
    # Model definition
end

register_model("my_model", my_model, 
    version="1.0.0",
    description="Custom inference model",
    parameters=Dict("learning_rate" => 0.01)
)
```
"""
function register_model(
    name::String,
    model_fn::Function;
    version::String = "1.0.0",
    description::String = "",
    parameters::Dict{String,Any} = Dict{String,Any}(),
)
    lock(GLOBAL_REGISTRY.lock) do
        if haskey(GLOBAL_REGISTRY.models, name)
            @warn "Model $name already registered, overwriting"
        end

        GLOBAL_REGISTRY.models[name] = Dict(
            "function" => model_fn,
            "metadata" => ModelMetadata(name, version, description, now(), parameters),
        )

        @info "Registered model" name=name version=version
    end
end

# Create a model instance
function create_model_instance(
    model_name::String;
    initial_state::Dict{String,Any} = Dict{String,Any}(),
)
    lock(GLOBAL_REGISTRY.lock) do
        if !haskey(GLOBAL_REGISTRY.models, model_name)
            throw(ArgumentError("Model $model_name not found in registry"))
        end

        model_def = GLOBAL_REGISTRY.models[model_name]
        instance_id = uuid4()

        instance = ModelInstance(
            instance_id,
            model_name,
            model_def["metadata"],
            initial_state,
            now(),
            now(),
        )

        GLOBAL_REGISTRY.instances[instance_id] = instance

        @info "Created model instance" model=model_name id=instance_id

        return instance
    end
end

# Delete a model instance
function delete_model_instance(instance_id::UUID)
    lock(GLOBAL_REGISTRY.lock) do
        if !haskey(GLOBAL_REGISTRY.instances, instance_id)
            throw(ArgumentError("Model instance $instance_id not found"))
        end

        instance = GLOBAL_REGISTRY.instances[instance_id]
        delete!(GLOBAL_REGISTRY.instances, instance_id)

        @info "Deleted model instance" model=instance.model_name id=instance_id

        return instance
    end
end

# Get model instance
function get_model_instance(instance_id::UUID)
    lock(GLOBAL_REGISTRY.lock) do
        if !haskey(GLOBAL_REGISTRY.instances, instance_id)
            throw(ArgumentError("Model instance $instance_id not found"))
        end

        instance = GLOBAL_REGISTRY.instances[instance_id]
        instance.last_used = now()

        return instance
    end
end

# Get model definition
function get_model_definition(model_name::String)
    lock(GLOBAL_REGISTRY.lock) do
        if !haskey(GLOBAL_REGISTRY.models, model_name)
            throw(ArgumentError("Model $model_name not found in registry"))
        end

        return GLOBAL_REGISTRY.models[model_name]
    end
end

"""
    get_model(model_name::String)

Get a registered model definition by name.

# Arguments
- `model_name::String`: Name of the model to retrieve

# Returns
- Model definition dictionary or `nothing` if not found

# Example
```julia
model = get_model("linear_regression")
```
"""
function get_model(model_name::String)
    lock(GLOBAL_REGISTRY.lock) do
        return get(GLOBAL_REGISTRY.models, model_name, nothing)
    end
end

"""
    unregister_model(name::String)

Remove a model from the global registry.

# Arguments
- `name::String`: Name of the model to unregister

# Returns
- `Bool`: `true` if model was removed, `false` if model was not found

# Example
```julia
unregister_model("my_model")
```
"""
function unregister_model(name::String)
    lock(GLOBAL_REGISTRY.lock) do
        if haskey(GLOBAL_REGISTRY.models, name)
            delete!(GLOBAL_REGISTRY.models, name)
            @info "Unregistered model" name=name
            return true
        else
            @warn "Model not found for unregistration" name=name
            return false
        end
    end
end

"""
    list_registered_models()

List all registered models with their metadata.

# Returns
- `Dict{String,Any}`: Dictionary mapping model names to their metadata

# Example
```julia
models = list_registered_models()
for (name, meta) in models
    println("\$name v\$(meta["version"]): \$(meta["description"])")
end
```
"""
function list_registered_models()
    return list_models()
end

# List all registered models
function list_models()
    lock(GLOBAL_REGISTRY.lock) do
        models = Dict{String,Any}()

        for (name, def) in GLOBAL_REGISTRY.models
            models[name] = def["metadata"]
        end

        return models
    end
end

# List all model instances
function list_model_instances()
    lock(GLOBAL_REGISTRY.lock) do
        instances = Vector{Dict{String,Any}}()

        for (id, instance) in GLOBAL_REGISTRY.instances
            push!(
                instances,
                Dict(
                    "id" => string(id),
                    "model_name" => instance.model_name,
                    "created_at" => instance.created_at,
                    "last_used" => instance.last_used,
                    "metadata" => instance.metadata,
                ),
            )
        end

        return instances
    end
end

# Cleanup old instances (for memory management)
function cleanup_old_instances(max_age_hours::Int = 24)
    lock(GLOBAL_REGISTRY.lock) do
        cutoff_time = now() - Hour(max_age_hours)
        to_delete = UUID[]

        for (id, instance) in GLOBAL_REGISTRY.instances
            if instance.last_used < cutoff_time
                push!(to_delete, id)
            end
        end

        for id in to_delete
            delete!(GLOBAL_REGISTRY.instances, id)
        end

        if !isempty(to_delete)
            @info "Cleaned up old instances" count=length(to_delete)
        end

        return length(to_delete)
    end
end
