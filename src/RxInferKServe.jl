module RxInferKServe

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

    # Client (v2 compatible)
    RxInferClient

# Include submodules
include("types.jl")

# Serialization module
module Serialization
using JSON3
using StructTypes
using Distributions
using RxInfer
include("serialization.jl")
end
using .Serialization

# Models module
include("models/models.jl")
using .Models

# Include KServe v2 support (needs Models and Serialization)
include("grpc/kserve_v2.jl")
using .KServeV2

# Server modules
include("server/config.jl")
include("server/middleware.jl")
include("server/handlers.jl")
include("server/server.jl")

# Client module
include("client/client.jl")

# Package initialization
function __init__()
    @info "RxInferKServe.jl loaded" version=pkgversion(@__MODULE__)
end

end # module
