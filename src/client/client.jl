# Julia client for RxInferKServe (KServe v2 compatible)

using HTTP
using JSON3
using UUIDs

"""
    RxInferClient

Client for communicating with RxInferKServe servers using the KServe v2 protocol.

# Fields
- `base_url::String`: Base URL of the server
- `api_key::Union{String,Nothing}`: Optional API key for authentication
- `timeout::Int`: Request timeout in seconds

# Example
```julia
client = RxInferClient("http://localhost:8080")
models = client_list_models(client)
```
"""
struct RxInferClient
    base_url::String
    api_key::Union{String,Nothing}
    timeout::Int
end

"""
    RxInferClient(base_url="http://localhost:8080"; api_key=nothing, timeout=30)

Create a new RxInferKServe client.

# Arguments
- `base_url::String="http://localhost:8080"`: Server base URL
- `api_key::Union{String,Nothing}=nothing`: Optional API key for authentication
- `timeout::Int=30`: Request timeout in seconds

# Example
```julia
# Basic client
client = RxInferClient()

# Client with authentication
client = RxInferClient("https://api.example.com", api_key="secret")
```
"""
function RxInferClient(
    base_url::String = "http://localhost:8080";
    api_key::Union{String,Nothing} = nothing,
    timeout::Int = 30,
)
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
        timeout = client.timeout,
    )

    return JSON3.read(response.body)
end

# Server readiness check
function ready_check(client::RxInferClient)
    response = HTTP.get(
        "$(client.base_url)/v2/health/ready",
        client_headers(client);
        timeout = client.timeout,
    )

    return JSON3.read(response.body)
end

"""
    client_list_models(client::RxInferClient)

List all available models on the server.

# Arguments
- `client::RxInferClient`: The client instance

# Returns
- `Dict`: Dictionary containing model information

# Example
```julia
client = RxInferClient()
models = client_list_models(client)
for model in models["models"]
    println(model["name"], " - ", model["state"])
end
```
"""
function client_list_models(client::RxInferClient)
    response = HTTP.get(
        "$(client.base_url)/v2/models",
        client_headers(client);
        timeout = client.timeout,
    )

    return JSON3.read(response.body)
end

# Get model metadata
function get_model_metadata(client::RxInferClient, model_name::String)
    response = HTTP.get(
        "$(client.base_url)/v2/models/$(model_name)",
        client_headers(client);
        timeout = client.timeout,
    )

    return JSON3.read(response.body)
end

# Check if model is ready
function is_model_ready(client::RxInferClient, model_name::String)
    response = HTTP.get(
        "$(client.base_url)/v2/models/$(model_name)/ready",
        client_headers(client);
        timeout = client.timeout,
    )

    return JSON3.read(response.body)["ready"]
end

"""
    run_inference(client, model_name, inputs; outputs=nothing, parameters=nothing, id=nothing)

Run inference on a model using the KServe v2 protocol.

# Arguments
- `client::RxInferClient`: The client instance
- `model_name::String`: Name of the model
- `inputs::Vector{Dict{String,Any}}`: Input tensors

# Keyword Arguments
- `outputs::Union{Vector{Dict{String,Any}},Nothing}=nothing`: Requested output tensors
- `parameters::Union{Dict{String,Any},Nothing}=nothing`: Additional parameters
- `id::Union{String,Nothing}=nothing`: Request ID

# Returns
- `Dict`: Inference results containing output tensors

# Example
```julia
client = RxInferClient()
inputs = [
    Dict(
        "name" => "observations",
        "shape" => [2, 1],
        "datatype" => "FP64",
        "data" => [1.0, 2.0]
    )
]
result = run_inference(client, "linear_model", inputs)
```
"""
function run_inference(
    client::RxInferClient,
    model_name::String,
    inputs::Vector{Dict{String,Any}};
    outputs::Union{Vector{Dict{String,Any}},Nothing} = nothing,
    parameters::Union{Dict{String,Any},Nothing} = nothing,
    id::Union{String,Nothing} = nothing,
)

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
        timeout = client.timeout,
    )

    return JSON3.read(response.body)
end
