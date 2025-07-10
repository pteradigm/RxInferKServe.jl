# Core type definitions for RxInferKServe

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


"""
    ServerConfig

Configuration settings for the RxInferKServe server.

# Fields
- `host::String = "127.0.0.1"`: Server host address
- `port::Int = 8080`: Server port number
- `workers::Int = 1`: Number of worker processes
- `log_level::String = "info"`: Logging level (debug, info, warn, error)
- `enable_cors::Bool = true`: Enable CORS headers
- `enable_auth::Bool = false`: Enable API key authentication
- `api_keys::Vector{String} = String[]`: List of valid API keys
- `max_request_size::Int = 10_000_000`: Maximum request size in bytes (10MB)
- `timeout_seconds::Int = 300`: Request timeout in seconds
- `enable_metrics::Bool = true`: Enable metrics collection

# Example
```julia
config = ServerConfig(
    host = "0.0.0.0",
    port = 8080,
    log_level = "debug",
    enable_auth = true,
    api_keys = ["secret-key-1", "secret-key-2"]
)
```
"""
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
