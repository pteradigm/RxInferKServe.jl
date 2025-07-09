# KServe v2 HTTP Handlers

module KServeV2HTTPHandlers

using HTTP
using JSON3
using UUIDs
using Logging
using ..KServeV2Types
using ...Models:
    GLOBAL_REGISTRY,
    get_model,
    create_model_instance,
    delete_model_instance,
    infer,
    list_models
using ...Serialization: serialize_inference_results, deserialize_inference_data

export handle_v2_health_live, handle_v2_health_ready
export handle_v2_model_ready, handle_v2_models_list
export handle_v2_model_metadata, handle_v2_model_infer
export route_v2_request

# Server liveness endpoint - GET /v2/health/live
function handle_v2_health_live(request::HTTP.Request)
    return HTTP.Response(
        200,
        ["Content-Type" => "application/json"],
        JSON3.write(Dict("live" => true)),
    )
end

# Server readiness endpoint - GET /v2/health/ready
function handle_v2_health_ready(request::HTTP.Request)
    # Check if server is ready to handle requests
    ready = true  # Could add more sophisticated readiness checks

    return HTTP.Response(
        200,
        ["Content-Type" => "application/json"],
        JSON3.write(Dict("ready" => ready)),
    )
end

# Model readiness endpoint - GET /v2/models/{model_name}[/versions/{model_version}]/ready
function handle_v2_model_ready(
    request::HTTP.Request,
    model_name::String,
    model_version::Union{String,Nothing},
)
    # Check if model exists
    model = get_model(model_name)
    if isnothing(model)
        return HTTP.Response(
            404,
            ["Content-Type" => "application/json"],
            JSON3.write(Dict("error" => "Model not found: $model_name")),
        )
    end

    # For now, if model exists, it's ready
    return HTTP.Response(
        200,
        ["Content-Type" => "application/json"],
        JSON3.write(Dict("ready" => true)),
    )
end

# List models endpoint - GET /v2/models
function handle_v2_models_list(request::HTTP.Request)
    models = String[]

    for (name, _) in GLOBAL_REGISTRY.models
        push!(models, name)
    end

    return HTTP.Response(
        200,
        ["Content-Type" => "application/json"],
        JSON3.write(Dict("models" => models)),
    )
end

# Model metadata endpoint - GET /v2/models/{model_name}[/versions/{model_version}]
function handle_v2_model_metadata(
    request::HTTP.Request,
    model_name::String,
    model_version::Union{String,Nothing},
)
    model = get_model(model_name)
    if isnothing(model)
        return HTTP.Response(
            404,
            ["Content-Type" => "application/json"],
            JSON3.write(Dict("error" => "Model not found: $model_name")),
        )
    end

    # Extract metadata from model dict
    metadata = model["metadata"]

    # Convert to KServe v2 format
    response = Dict(
        "name" => model_name,
        "versions" => [something(model_version, metadata.version)],
        "platform" => "rxinfer",
        "inputs" => [
            Dict(
                "name" => "x",
                "datatype" => "FP64",
                "shape" => [-1],  # -1 indicates variable dimension
            ),
            Dict("name" => "y", "datatype" => "FP64", "shape" => [-1]),
        ],
        "outputs" => [
            Dict(
                "name" => "posteriors",
                "datatype" => "BYTES",  # JSON-encoded distributions
                "shape" => [-1],
            ),
            Dict("name" => "free_energy", "datatype" => "FP64", "shape" => [1]),
        ],
    )

    return HTTP.Response(200, ["Content-Type" => "application/json"], JSON3.write(response))
end

# Model inference endpoint - POST /v2/models/{model_name}[/versions/{model_version}]/infer
function handle_v2_model_infer(
    request::HTTP.Request,
    model_name::String,
    model_version::Union{String,Nothing},
)
    try
        # Parse request body
        body = JSON3.read(request.body, Dict{String,Any})

        # Extract request parameters
        request_id = get(body, "id", string(uuid4()))
        parameters = get(body, "parameters", Dict{String,Any}())
        inputs = get(body, "inputs", [])

        # Check if model exists
        model = get_model(model_name)
        if isnothing(model)
            return HTTP.Response(
                404,
                ["Content-Type" => "application/json"],
                JSON3.write(Dict("error" => "Model not found: $model_name")),
            )
        end

        # Create a temporary model instance for this inference
        instance = create_model_instance(model_name)

        try
            # Convert KServe tensor inputs to RxInfer data format
            data_dict = Dict{String,Any}()

            for input in inputs
                name = input["name"]
                datatype = input["datatype"]
                shape = input["shape"]
                data = input["data"]

                # Reshape flat data to original shape
                if length(shape) > 1
                    data_dict[name] = reshape(data, tuple(shape...))
                else
                    data_dict[name] = data
                end
            end

            # Convert parameters to Symbol keys for RxInfer
            symbol_params = Dict{Symbol,Any}()
            for (k, v) in parameters
                symbol_params[Symbol(k)] = v
            end

            # Run inference
            results, duration_ms = infer(
                instance.id,
                deserialize_inference_data(data_dict);
                iterations = get(parameters, "iterations", 10),
                options = symbol_params,
            )

            # Serialize results to KServe v2 format
            outputs = []

            # First serialize the results to handle Symbol/String conversion
            serialized_results = serialize_inference_results(results)

            # Add posteriors as JSON-encoded BYTES
            if haskey(serialized_results, "posteriors")
                posteriors_json = JSON3.write(serialized_results["posteriors"])
                push!(
                    outputs,
                    Dict(
                        "name" => "posteriors",
                        "datatype" => "BYTES",
                        "shape" => [1],
                        "data" => [posteriors_json],
                    ),
                )
            end

            # Add free energy as FP64
            if haskey(serialized_results, "free_energy")
                push!(
                    outputs,
                    Dict(
                        "name" => "free_energy",
                        "datatype" => "FP64",
                        "shape" => [1],
                        "data" => [serialized_results["free_energy"]],
                    ),
                )
            end

            # Add any other numeric results
            for (key, value) in serialized_results
                if key ∉ ["posteriors", "free_energy"] && value isa Number
                    push!(
                        outputs,
                        Dict(
                            "name" => key,
                            "datatype" => "FP64",
                            "shape" => [1],
                            "data" => [value],
                        ),
                    )
                end
            end

            # Create response
            response = Dict(
                "model_name" => model_name,
                "model_version" => something(model_version, "1.0.0"),
                "id" => request_id,
                "outputs" => outputs,
                "parameters" => Dict("inference_time_ms" => duration_ms),
            )

            return HTTP.Response(
                200,
                ["Content-Type" => "application/json"],
                JSON3.write(response),
            )

        finally
            # Clean up temporary instance
            delete_model_instance(instance.id)
        end

    catch e
        @error "Inference failed" exception=(e, catch_backtrace())
        return HTTP.Response(
            500,
            ["Content-Type" => "application/json"],
            JSON3.write(Dict("error" => "Inference failed: $(sprint(showerror, e))")),
        )
    end
end

# Route KServe v2 requests
function route_v2_request(request::HTTP.Request)
    method = request.method
    path = request.target

    # Remove query parameters
    path = split(path, '?')[1]

    # Remove /v2 prefix
    path = replace(path, "/v2" => "")

    # Parse path components
    parts = filter(!isempty, split(path, '/'))

    # Route based on path
    if isempty(parts)
        # Root v2 endpoint
        return HTTP.Response(
            200,
            ["Content-Type" => "application/json"],
            JSON3.write(Dict("version" => "v2")),
        )
    elseif parts[1] == "health"
        if length(parts) == 2 && parts[2] == "live" && method == "GET"
            return KServeV2HTTPHandlers.handle_v2_health_live(request)
        elseif length(parts) == 2 && parts[2] == "ready" && method == "GET"
            return KServeV2HTTPHandlers.handle_v2_health_ready(request)
        end
    elseif parts[1] == "models"
        if length(parts) == 1 && method == "GET"
            return KServeV2HTTPHandlers.handle_v2_models_list(request)
        elseif length(parts) >= 2
            model_name = String(parts[2])  # Convert SubString to String

            # Check for version in path
            model_version = nothing
            remaining_parts = parts[3:end]

            if length(remaining_parts) >= 2 && remaining_parts[1] == "versions"
                model_version = remaining_parts[2]
                remaining_parts = remaining_parts[3:end]
            end

            # Route based on remaining path
            if isempty(remaining_parts) && method == "GET"
                return KServeV2HTTPHandlers.handle_v2_model_metadata(
                    request,
                    model_name,
                    model_version,
                )
            elseif length(remaining_parts) == 1 &&
                   remaining_parts[1] == "ready" &&
                   method == "GET"
                return KServeV2HTTPHandlers.handle_v2_model_ready(
                    request,
                    model_name,
                    model_version,
                )
            elseif length(remaining_parts) == 1 &&
                   remaining_parts[1] == "infer" &&
                   method == "POST"
                return KServeV2HTTPHandlers.handle_v2_model_infer(
                    request,
                    model_name,
                    model_version,
                )
            end
        end
    end

    # Not found
    return HTTP.Response(
        404,
        ["Content-Type" => "application/json"],
        JSON3.write(
            Dict("error" => "Endpoint not found", "path" => path, "method" => method),
        ),
    )
end

end # module
