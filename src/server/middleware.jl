# HTTP middleware for the server

using HTTP
using JSON3
using Dates

# Logging middleware
function logging_middleware(handler)
    return function(request::HTTP.Request)
        start_time = time()
        method = request.method
        path = request.target
        
        # Generate request ID
        request_id = uuid4()
        
        @info "Request received" method=method path=path request_id=request_id
        
        try
            response = handler(request)
            duration_ms = (time() - start_time) * 1000
            
            @info "Request completed" method=method path=path status=response.status duration_ms=duration_ms request_id=request_id
            
            return response
        catch e
            duration_ms = (time() - start_time) * 1000
            @error "Request failed" method=method path=path error=e duration_ms=duration_ms request_id=request_id
            rethrow(e)
        end
    end
end

# Authentication middleware
function auth_middleware(handler)
    return function(request::HTTP.Request)
        config = get_config()
        
        if !config.enable_auth
            return handler(request)
        end
        
        # Check for API key in headers
        api_key = HTTP.header(request, "X-API-Key", "")
        
        if isempty(api_key)
            # Check Authorization header
            auth_header = HTTP.header(request, "Authorization", "")
            if startswith(auth_header, "Bearer ")
                api_key = auth_header[8:end]
            end
        end
        
        if !validate_api_key(api_key)
            return HTTP.Response(
                401,
                ["Content-Type" => "application/json"],
                JSON3.write(ErrorResponse(
                    "unauthorized",
                    "Invalid or missing API key",
                    nothing,
                    now(),
                    nothing
                ))
            )
        end
        
        return handler(request)
    end
end

# CORS middleware
function cors_middleware(handler)
    return function(request::HTTP.Request)
        config = get_config()
        
        if !config.enable_cors
            return handler(request)
        end
        
        # Handle preflight requests
        if request.method == "OPTIONS"
            return HTTP.Response(200, cors_headers(), "")
        end
        
        # Process request
        response = handler(request)
        
        # Add CORS headers to response
        for (key, value) in cors_headers()
            HTTP.setheader(response, key => value)
        end
        
        return response
    end
end

# Error handling middleware
function error_middleware(handler)
    return function(request::HTTP.Request)
        try
            return handler(request)
        catch e
            # Generate error response
            error_type = string(typeof(e))
            error_message = string(e)
            
            # Determine status code
            status = if e isa ArgumentError
                400  # Bad Request
            elseif e isa KeyError || e isa BoundsError
                404  # Not Found
            elseif e isa MethodError
                501  # Not Implemented
            else
                500  # Internal Server Error
            end
            
            # Create error response
            error_response = ErrorResponse(
                error_type,
                error_message,
                Dict("stacktrace" => string(stacktrace())),
                now(),
                nothing
            )
            
            return HTTP.Response(
                status,
                ["Content-Type" => "application/json"],
                JSON3.write(error_response)
            )
        end
    end
end

# Request size limiting middleware
function size_limit_middleware(handler)
    return function(request::HTTP.Request)
        config = get_config()
        
        # Check Content-Length header
        content_length = parse(Int, HTTP.header(request, "Content-Length", "0"))
        
        if content_length > config.max_request_size
            return HTTP.Response(
                413,
                ["Content-Type" => "application/json"],
                JSON3.write(ErrorResponse(
                    "payload_too_large",
                    "Request body exceeds maximum size of $(config.max_request_size) bytes",
                    Dict("content_length" => content_length),
                    now(),
                    nothing
                ))
            )
        end
        
        return handler(request)
    end
end

# Compose all middleware
function create_middleware_stack(handler)
    return handler |>
           error_middleware |>
           auth_middleware |>
           size_limit_middleware |>
           cors_middleware |>
           logging_middleware
end