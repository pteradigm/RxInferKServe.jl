# HTTP request handlers

using HTTP
using JSON3
using UUIDs

# Route request to appropriate handler
function route_request(request::HTTP.Request)
    method = request.method
    path = request.target
    
    # Remove query parameters
    path = split(path, '?')[1]
    
    # Only handle v2 API (KServe v2 protocol)
    if startswith(path, "/v2")
        # Delegate to KServe v2 handler
        return KServeV2.route_v2_request(request)
    else
        return HTTP.Response(
            404,
            ["Content-Type" => "application/json"],
            JSON3.write(Dict(
                "error" => "not_found",
                "message" => "Only KServe v2 API is supported. Use /v2 prefix"
            ))
        )
    end
end