# Core type definitions for RxInferMLServer

using StructTypes
using Dates
using UUIDs

# Model metadata
struct ModelMetadata
    name::String
    version::String
    description::String
    created_at::DateTime
    parameters::Dict{String,Any}
end

StructTypes.StructType(::Type{ModelMetadata}) = StructTypes.Struct()

# Model instance
mutable struct ModelInstance
    id::UUID
    model_name::String
    metadata::ModelMetadata
    state::Dict{String,Any}
    created_at::DateTime
    last_used::DateTime
end

StructTypes.StructType(::Type{ModelInstance}) = StructTypes.Struct()

# Inference request
struct InferenceRequest
    model_id::UUID
    data::Dict{String,Any}
    parameters::Dict{String,Any}
    request_id::Union{UUID,Nothing}
end

StructTypes.StructType(::Type{InferenceRequest}) = StructTypes.Struct()

# Inference response
struct InferenceResponse
    request_id::UUID
    model_id::UUID
    results::Dict{String,Any}
    metadata::Dict{String,Any}
    timestamp::DateTime
    duration_ms::Float64
end

StructTypes.StructType(::Type{InferenceResponse}) = StructTypes.Struct()

# Server configuration
@kwdef struct ServerConfig
    host::String = "127.0.0.1"
    port::Int = 8080
    workers::Int = 1
    log_level::String = "info"
    enable_cors::Bool = true
    enable_auth::Bool = false
    api_keys::Vector{String} = String[]
    max_request_size::Int = 10_000_000  # 10MB
    timeout_seconds::Int = 300
    enable_metrics::Bool = true
end

StructTypes.StructType(::Type{ServerConfig}) = StructTypes.Struct()

# Error response
struct ErrorResponse
    error::String
    message::String
    details::Union{Dict{String,Any},Nothing}
    timestamp::DateTime
    request_id::Union{UUID,Nothing}
end

StructTypes.StructType(::Type{ErrorResponse}) = StructTypes.Struct()

# Health check response
struct HealthResponse
    status::String
    version::String
    uptime_seconds::Float64
    models_loaded::Int
    timestamp::DateTime
end

StructTypes.StructType(::Type{HealthResponse}) = StructTypes.Struct()