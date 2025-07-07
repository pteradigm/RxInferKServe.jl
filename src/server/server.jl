# Main server implementation

using HTTP
using Sockets

# Global server state
const SERVER_START_TIME = Ref{Float64}()
const SERVER_INSTANCE = Ref{HTTP.Server}()

# Start the server
function start_server(; host="127.0.0.1", port=8080, kwargs...)
    # Initialize configuration
    config = init_config(; host=host, port=port, kwargs...)
    
    # Set start time
    SERVER_START_TIME[] = time()
    
    # Register built-in models
    register_builtin_models()
    
    # Create request handler with middleware
    handler = create_middleware_stack(route_request)
    
    @info "Starting RxInferMLServer" host=config.host port=config.port
    
    # Create and start server
    server = HTTP.serve!(handler, config.host, config.port)
    SERVER_INSTANCE[] = server
    
    @info "Server started successfully" url="http://$(config.host):$(config.port)/v1"
    
    return server
end

# Stop the server
function stop_server()
    if !isassigned(SERVER_INSTANCE)
        @warn "Server not running"
        return
    end
    
    server = SERVER_INSTANCE[]
    close(server)
    
    @info "Server stopped"
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