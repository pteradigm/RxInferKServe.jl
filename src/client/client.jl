# Julia client for RxInferMLServer

using HTTP
using JSON3
using UUIDs

struct RxInferClient
    base_url::String
    api_key::Union{String,Nothing}
    timeout::Int
end

# Constructor
function RxInferClient(base_url::String="http://localhost:8080/v1"; 
                      api_key::Union{String,Nothing}=nothing,
                      timeout::Int=30)
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

# Health check
function health_check(client::RxInferClient)
    response = HTTP.get(
        "$(client.base_url)/health",
        client_headers(client);
        timeout=client.timeout
    )
    
    return JSON3.read(response.body, HealthResponse)
end

# List available models
function list_models(client::RxInferClient)
    response = HTTP.get(
        "$(client.base_url)/models",
        client_headers(client);
        timeout=client.timeout
    )
    
    return JSON3.read(response.body)
end

# List model instances
function list_instances(client::RxInferClient)
    response = HTTP.get(
        "$(client.base_url)/models/instances",
        client_headers(client);
        timeout=client.timeout
    )
    
    return JSON3.read(response.body)
end

# Create model instance
function create_instance(client::RxInferClient, model_name::String; 
                        initial_state::Dict{String,Any}=Dict{String,Any}())
    body = Dict(
        "model_name" => model_name,
        "initial_state" => initial_state
    )
    
    response = HTTP.post(
        "$(client.base_url)/models/instances",
        client_headers(client),
        JSON3.write(body);
        timeout=client.timeout
    )
    
    return JSON3.read(response.body)
end

# Delete model instance
function delete_instance(client::RxInferClient, instance_id::Union{String,UUID})
    id_str = string(instance_id)
    
    response = HTTP.delete(
        "$(client.base_url)/models/instances/$(id_str)",
        client_headers(client);
        timeout=client.timeout
    )
    
    return JSON3.read(response.body)
end

# Run inference
function run_inference(client::RxInferClient, instance_id::Union{String,UUID}, 
                      data::Dict; parameters::Dict=Dict(), request_id::Union{String,UUID,Nothing}=nothing)
    id_str = string(instance_id)
    
    body = Dict(
        "data" => data,
        "parameters" => parameters
    )
    
    if !isnothing(request_id)
        body["request_id"] = string(request_id)
    end
    
    response = HTTP.post(
        "$(client.base_url)/models/instances/$(id_str)/infer",
        client_headers(client),
        JSON3.write(body);
        timeout=client.timeout
    )
    
    return JSON3.read(response.body, InferenceResponse)
end