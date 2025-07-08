# Model registry for managing RxInfer models

using UUIDs
using Dates
using Base.Threads

mutable struct ModelRegistry
    models::Dict{String,Any}  # Model name -> model definition
    instances::Dict{UUID,ModelInstance}  # Instance ID -> instance
    lock::ReentrantLock
end

# Global registry instance
const GLOBAL_REGISTRY =
    ModelRegistry(Dict{String,Any}(), Dict{UUID,ModelInstance}(), ReentrantLock())

# Register a model definition
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

# Alias for compatibility with KServe handlers
function get_model(model_name::String)
    lock(GLOBAL_REGISTRY.lock) do
        return get(GLOBAL_REGISTRY.models, model_name, nothing)
    end
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
