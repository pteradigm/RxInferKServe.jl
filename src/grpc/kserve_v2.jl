# KServe v2 Protocol Implementation

module KServeV2

# Include generated protobuf types
include("kserve/kserve.jl")
using .kserve.v2

# Include KServe v2 modules
include("types.jl")
include("http_handlers.jl")
include("grpc_server.jl")

using .KServeV2Types
using .KServeV2HTTPHandlers
using .KServeV2GRPCServer

# Re-export main functions
export route_v2_request
export start_grpc_server, stop_grpc_server
export KServeV2Types, KServeV2HTTPHandlers, KServeV2GRPCServer

end # module