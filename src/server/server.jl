# Main server implementation

using HTTP
using Sockets
using ..Models: register_builtin_models

# Global server state
const SERVER_START_TIME = Ref{Float64}()
const SERVER_INSTANCE = Ref{HTTP.Server}()
const GRPC_SERVER_INSTANCE =
    Ref{Union{KServeV2.KServeV2GRPCServer.GRPCServer,Nothing}}(nothing)

# Start the server
function start_server(;
    host = "127.0.0.1",
    port = 8080,
    grpc_port = 8081,
    enable_grpc = true,
    kwargs...,
)
    # Initialize configuration
    config = init_config(; host = host, port = port, kwargs...)

    # Set start time
    SERVER_START_TIME[] = time()

    # Register built-in models
    register_builtin_models()

    # Create request handler with middleware
    handler = create_middleware_stack(route_request)

    @info "Starting RxInferKServe" host=config.host port=config.port

    # Create and start HTTP server
    server = HTTP.serve!(handler, config.host, config.port)
    SERVER_INSTANCE[] = server

    @info "HTTP server started successfully"
    url="http://$(config.host):$(config.port)/v2"

    # Start gRPC server if enabled
    if enable_grpc
        try
            grpc_server = KServeV2.start_grpc_server(; host = config.host, port = grpc_port)
            GRPC_SERVER_INSTANCE[] = grpc_server
            @info "gRPC server started successfully" grpc_url="$(config.host):$(grpc_port)"
        catch e
            @warn "Failed to start gRPC server" exception=(e, catch_backtrace())
        end
    end

    return server
end

# Stop the server
function stop_server()
    # Stop HTTP server
    if isassigned(SERVER_INSTANCE)
        server = SERVER_INSTANCE[]
        close(server)
        @info "HTTP server stopped"
    else
        @warn "HTTP server not running"
    end

    # Stop gRPC server
    if !isnothing(GRPC_SERVER_INSTANCE[])
        KServeV2.stop_grpc_server(GRPC_SERVER_INSTANCE[])
        GRPC_SERVER_INSTANCE[] = nothing
    end
end

# Run server with graceful shutdown
function run_server(; kwargs...)
    server = start_server(; kwargs...)

    # Set up signal handlers for graceful shutdown
    try
        @info "Server running. Press Ctrl+C to stop."
        wait(server)
    catch e
        if e isa InterruptException
            @info "Shutting down server..."
            stop_server()
        else
            rethrow(e)
        end
    end
end
