# Julia client for RxInferKServe (KServe v2 compatible)

using HTTP
using JSON3
using UUIDs

struct RxInferClient
    base_url::String
    api_key::Union{String,Nothing}
    timeout::Int
end

# Constructor
function RxInferClient(base_url::String="http://localhost:8080"; 
                      api_key::Union{String,Nothing}=nothing,
                      timeout::Int=30)
    # Ensure base_url doesn't end with slash
    base_url = rstrip(base_url, '/')
    return RxInferClient(base_url, api_key, timeout)
end

# Helper to create headers
function client_headers(client::RxInferClient)
    headers = ["Content-Type" => "application/json"]
    
    if !isnothing(client.api_key)
        push!(headers, "X-API-Key" => client.api_key)
    end
    
    return headers
end

# Health check - KServe v2 liveness endpoint
function health_check(client::RxInferClient)
    response = HTTP.get(
        "$(client.base_url)/v2/health/live",
        client_headers(client);
        timeout=client.timeout
    )
    
    return JSON3.read(response.body)
end

# Server readiness check
function ready_check(client::RxInferClient)
    response = HTTP.get(
        "$(client.base_url)/v2/health/ready",
        client_headers(client);
        timeout=client.timeout
    )
    
    return JSON3.read(response.body)
end

# List available models
function client_list_models(client::RxInferClient)
    response = HTTP.get(
        "$(client.base_url)/v2/models",
        client_headers(client);
        timeout=client.timeout
    )
    
    return JSON3.read(response.body)
end

# Get model metadata
function get_model_metadata(client::RxInferClient, model_name::String)
    response = HTTP.get(
        "$(client.base_url)/v2/models/$(model_name)",
        client_headers(client);
        timeout=client.timeout
    )
    
    return JSON3.read(response.body)
end

# Check if model is ready
function is_model_ready(client::RxInferClient, model_name::String)
    response = HTTP.get(
        "$(client.base_url)/v2/models/$(model_name)/ready",
        client_headers(client);
        timeout=client.timeout
    )
    
    return JSON3.read(response.body)["ready"]
end

# Run inference - KServe v2 format
function run_inference(client::RxInferClient, model_name::String,
                      inputs::Vector{Dict{String,Any}};
                      outputs::Union{Vector{Dict{String,Any}},Nothing}=nothing,
                      parameters::Union{Dict{String,Any},Nothing}=nothing,
                      id::Union{String,Nothing}=nothing)
    
    body = Dict{String,Any}("inputs" => inputs)
    
    if !isnothing(outputs)
        body["outputs"] = outputs
    end
    
    if !isnothing(parameters)
        body["parameters"] = parameters
    end
    
    if !isnothing(id)
        body["id"] = id
    end
    
    response = HTTP.post(
        "$(client.base_url)/v2/models/$(model_name)/infer",
        client_headers(client),
        JSON3.write(body);
        timeout=client.timeout
    )
    
    return JSON3.read(response.body)
end