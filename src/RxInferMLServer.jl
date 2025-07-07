module RxInferMLServer

using HTTP
using JSON3
using StructTypes
using RxInfer
using Logging
using Dates
using UUIDs
using Sockets

# Export main functionality
export 
    # Server
    start_server,
    stop_server,
    ServerConfig,
    
    # Models
    ModelRegistry,
    register_model,
    create_model_instance,
    delete_model_instance,
    list_models,
    
    # Inference
    infer,
    InferenceRequest,
    InferenceResponse,
    
    # Client
    RxInferClient

# Include submodules
include("types.jl")
include("serialization.jl")
include("models/registry.jl")
include("models/base.jl")
include("server/config.jl")
include("server/middleware.jl")
include("server/handlers.jl")
include("server/server.jl")
include("client/client.jl")

# Package initialization
function __init__()
    @info "RxInferMLServer.jl loaded" version=pkgversion(@__MODULE__)
end

end # module