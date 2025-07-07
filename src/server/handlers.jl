# HTTP request handlers

using HTTP
using JSON3
using UUIDs

# Health check endpoint
function handle_health(request::HTTP.Request)
    uptime = time() - SERVER_START_TIME[]
    
    health = HealthResponse(
        "healthy",
        string(pkgversion(RxInferMLServer)),
        uptime,
        length(GLOBAL_REGISTRY.instances),
        now()
    )
    
    return HTTP.Response(
        200,
        ["Content-Type" => "application/json"],
        JSON3.write(health)
    )
end

# List models endpoint
function handle_list_models(request::HTTP.Request)
    models = list_models()
    
    return HTTP.Response(
        200,
        ["Content-Type" => "application/json"],
        JSON3.write(models)
    )
end

# List model instances endpoint
function handle_list_instances(request::HTTP.Request)
    instances = list_model_instances()
    
    return HTTP.Response(
        200,
        ["Content-Type" => "application/json"],
        JSON3.write(instances)
    )
end

# Create model instance endpoint
function handle_create_instance(request::HTTP.Request)
    # Parse request body
    body = JSON3.read(request.body, Dict{String,Any})
    
    model_name = get(body, "model_name", nothing)
    if isnothing(model_name)
        throw(ArgumentError("model_name is required"))
    end
    
    initial_state = get(body, "initial_state", Dict{String,Any}())
    
    # Create instance
    instance = create_model_instance(model_name; initial_state=initial_state)
    
    # Return instance details
    response = Dict(
        "id" => string(instance.id),
        "model_name" => instance.model_name,
        "created_at" => instance.created_at,
        "metadata" => instance.metadata
    )
    
    return HTTP.Response(
        201,
        ["Content-Type" => "application/json"],
        JSON3.write(response)
    )
end

# Delete model instance endpoint
function handle_delete_instance(request::HTTP.Request)
    # Extract instance ID from path
    path_parts = split(request.target, '/')
    instance_id_str = path_parts[end]
    
    try
        instance_id = UUID(instance_id_str)
    catch
        throw(ArgumentError("Invalid instance ID format"))
    end
    
    # Delete instance
    instance = delete_model_instance(instance_id)
    
    return HTTP.Response(
        200,
        ["Content-Type" => "application/json"],
        JSON3.write(Dict("message" => "Instance deleted", "id" => string(instance_id)))
    )
end

# Inference endpoint
function handle_inference(request::HTTP.Request)
    # Extract instance ID from path
    path_parts = split(request.target, '/')
    instance_id_idx = findfirst(x -> x == "instances", path_parts)
    
    if isnothing(instance_id_idx) || instance_id_idx >= length(path_parts)
        throw(ArgumentError("Invalid inference endpoint path"))
    end
    
    instance_id_str = path_parts[instance_id_idx + 1]
    
    try
        instance_id = UUID(instance_id_str)
    catch
        throw(ArgumentError("Invalid instance ID format"))
    end
    
    # Parse request body
    body = JSON3.read(request.body, Dict{String,Any})
    
    # Extract data and parameters
    data = get(body, "data", Dict{String,Any}())
    parameters = get(body, "parameters", Dict{String,Any}())
    request_id = get(body, "request_id", nothing)
    
    # Deserialize data
    data_symbols = deserialize_inference_data(data)
    
    # Run inference
    results, duration_ms = infer(
        instance_id,
        data_symbols;
        iterations = get(parameters, "iterations", 10),
        options = parameters
    )
    
    # Serialize results
    serialized_results = serialize_inference_results(results)
    
    # Create response
    response = InferenceResponse(
        isnothing(request_id) ? uuid4() : UUID(request_id),
        instance_id,
        serialized_results,
        Dict("inference_time_ms" => duration_ms),
        now(),
        duration_ms
    )
    
    return HTTP.Response(
        200,
        ["Content-Type" => "application/json"],
        JSON3.write(response)
    )
end

# Route request to appropriate handler
function route_request(request::HTTP.Request)
    method = request.method
    path = request.target
    
    # Remove query parameters
    path = split(path, '?')[1]
    
    # API versioning
    if !startswith(path, "/v1")
        return HTTP.Response(
            404,
            ["Content-Type" => "application/json"],
            JSON3.write(ErrorResponse(
                "not_found",
                "API version not found. Use /v1 prefix",
                nothing,
                now(),
                nothing
            ))
        )
    end
    
    # Remove version prefix
    path = replace(path, "/v1" => "")
    
    # Route based on path and method
    if path == "/health" && method == "GET"
        return handle_health(request)
    elseif path == "/models" && method == "GET"
        return handle_list_models(request)
    elseif path == "/models/instances" && method == "GET"
        return handle_list_instances(request)
    elseif path == "/models/instances" && method == "POST"
        return handle_create_instance(request)
    elseif startswith(path, "/models/instances/") && endswith(path, "/infer") && method == "POST"
        return handle_inference(request)
    elseif startswith(path, "/models/instances/") && method == "DELETE"
        return handle_delete_instance(request)
    else
        return HTTP.Response(
            404,
            ["Content-Type" => "application/json"],
            JSON3.write(ErrorResponse(
                "not_found",
                "Endpoint not found",
                Dict("path" => path, "method" => method),
                now(),
                nothing
            ))
        )
    end
end