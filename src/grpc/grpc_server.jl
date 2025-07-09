# KServe v2 gRPC Server Implementation

module KServeV2GRPCServer

using Sockets
using HTTP
using ProtoBuf
using ProtoBuf: OneOf
using JSON3
using Logging
using UUIDs
using ..kserve.v2
using ..KServeV2Types
using ..kserve.v2: ModelMetadataResponse, ModelInferRequest, ModelInferResponse
# Import protobuf types with their full names
const TensorMetadata = v2.var"ModelMetadataResponse.TensorMetadata"
const InferRequestedOutputTensor = v2.var"ModelInferRequest.InferRequestedOutputTensor"
const InferInputTensor = v2.var"ModelInferRequest.InferInputTensor"
const InferOutputTensor = v2.var"ModelInferResponse.InferOutputTensor"
using ...Models:
    GLOBAL_REGISTRY, get_model, create_model_instance, delete_model_instance, infer
using ...Serialization: serialize_inference_results, deserialize_inference_data

export GRPCServer, start_grpc_server, stop_grpc_server
export handle_grpc_request

# gRPC Server structure
mutable struct GRPCServer
    host::String
    port::Int
    server::Union{HTTP.Server,Nothing}
    running::Bool
end

# gRPC method handlers
function handle_server_live(request::ServerLiveRequest)
    ServerLiveResponse(true)  # live=true
end

function handle_server_ready(request::ServerReadyRequest)
    ServerReadyResponse(true)  # ready=true
end

function handle_model_ready(request::ModelReadyRequest)
    model = get_model(request.name)
    ready = !isnothing(model)
    ModelReadyResponse(ready)  # ready
end

function handle_server_metadata(request::ServerMetadataRequest)
    ServerMetadataResponse(
        "RxInferKServe",        # name
        "0.1.0",                # version (TODO: Get from package version)
        ["rxinfer", "probabilistic"],  # extensions
    )
end

function handle_model_metadata(request::ModelMetadataRequest)
    model = get_model(request.name)
    if isnothing(model)
        throw(ArgumentError("Model not found: $(request.name)"))
    end

    metadata = model["metadata"]

    # Convert metadata to protobuf format
    inputs = TensorMetadata[]
    # Get inputs from metadata parameters or use defaults
    inputs_spec = get(
        metadata.parameters,
        "inputs",
        [Dict("name" => "data", "datatype" => "FP64", "shape" => [-1, -1])],
    )
    for input in inputs_spec
        push!(inputs, TensorMetadata(
            input["name"],      # name
            input["datatype"],   # datatype
            input["shape"],       # shape
        ))
    end

    outputs = TensorMetadata[]
    outputs_spec = get(metadata.parameters, "outputs", [])
    for output in outputs_spec
        push!(outputs, TensorMetadata(
            output["name"],      # name
            output["datatype"],   # datatype
            output["shape"],       # shape
        ))
    end

    ModelMetadataResponse(
        request.name,                                # name
        [something(request.version, "1.0.0")],      # versions
        "rxinfer",                                  # platform
        inputs,                                      # inputs
        outputs,                                      # outputs
    )
end

function handle_model_infer(request::ModelInferRequest)
    model = get_model(request.model_name)
    if isnothing(model)
        throw(ArgumentError("Model not found: $(request.model_name)"))
    end

    # Create temporary instance
    instance = create_model_instance(request.model_name)

    try
        # Convert tensor inputs to RxInfer format
        data_dict = Dict{String,Any}()

        for input in request.inputs
            if !isnothing(input.contents)
                data = convert_from_kserve_tensor(input.contents)
                data_dict[input.name] = data
            end
        end

        # Extract parameters and convert to Symbol keys
        params = Dict{Symbol,Any}()
        for (k, v) in request.parameters
            params[Symbol(k)] = extract_parameter_value(v)
        end

        # Run inference
        results, duration_ms = infer(
            instance.id,
            deserialize_inference_data(data_dict);
            iterations = get(params, :iterations, 10),
            options = params,
        )

        # Convert results to tensor outputs
        outputs = InferOutputTensor[]

        # Handle posteriors
        if haskey(results, :posteriors)
            # Serialize the posteriors to get String keys
            serialized =
                serialize_inference_results(Dict(:posteriors => results[:posteriors]))
            posteriors_json = JSON3.write(serialized["posteriors"])
            bytes_data = InferTensorContents(
                Vector{Bool}(),
                Vector{Int32}(),
                Vector{Int64}(),
                Vector{UInt32}(),
                Vector{UInt64}(),
                Vector{Float32}(),
                Vector{Float64}(),
                [Vector{UInt8}(posteriors_json)],
            )
            push!(
                outputs,
                InferOutputTensor(
                    "posteriors",
                    "BYTES",
                    [1],
                    Dict{String,InferParameter}(),
                    bytes_data,
                ),
            )
        end

        # Handle free energy
        if haskey(results, :free_energy)
            fe_contents = convert_to_kserve_tensor("free_energy", [results[:free_energy]])
            push!(
                outputs,
                InferOutputTensor(
                    "free_energy",
                    "FP64",
                    [1],
                    Dict{String,InferParameter}(),
                    fe_contents,
                ),
            )
        end

        # Create response
        ModelInferResponse(
            request.model_name,
            something(request.model_version, "1.0.0"),
            something(request.id, string(uuid4())),
            Dict(
                "inference_time_ms" =>
                    InferParameter(ProtoBuf.OneOf(:int64_param, round(Int64, duration_ms))),
            ),
            outputs,
            Vector{Vector{UInt8}}(),
        )

    finally
        delete_model_instance(instance.id)
    end
end

# Extract value from InferParameter
function extract_parameter_value(param::InferParameter)
    if isnothing(param.parameter_choice)
        return nothing
    end

    return param.parameter_choice.value
end

# gRPC request handler
function handle_grpc_request(request::HTTP.Request)
    # Extract gRPC method from path
    path = request.target

    # gRPC paths follow format: /package.Service/Method
    if !startswith(path, "/kserve.v2.GRPCInferenceService/")
        return HTTP.Response(
            404,
            ["grpc-status" => "12", "grpc-message" => "Method not found"],
            "",
        )
    end

    method_name = replace(path, "/kserve.v2.GRPCInferenceService/" => "")

    try
        # Decode request based on method
        response = if method_name == "ServerLive"
            req = PB.decode(PB.ProtoDecoder(IOBuffer(request.body)), ServerLiveRequest)
            handle_server_live(req)
        elseif method_name == "ServerReady"
            req = PB.decode(PB.ProtoDecoder(IOBuffer(request.body)), ServerReadyRequest)
            handle_server_ready(req)
        elseif method_name == "ModelReady"
            req = PB.decode(PB.ProtoDecoder(IOBuffer(request.body)), ModelReadyRequest)
            handle_model_ready(req)
        elseif method_name == "ServerMetadata"
            req = PB.decode(PB.ProtoDecoder(IOBuffer(request.body)), ServerMetadataRequest)
            handle_server_metadata(req)
        elseif method_name == "ModelMetadata"
            req = PB.decode(PB.ProtoDecoder(IOBuffer(request.body)), ModelMetadataRequest)
            handle_model_metadata(req)
        elseif method_name == "ModelInfer"
            req = PB.decode(PB.ProtoDecoder(IOBuffer(request.body)), ModelInferRequest)
            handle_model_infer(req)
        else
            throw(ArgumentError("Unknown method: $method_name"))
        end

        # Encode response
        io = IOBuffer()
        PB.encode(PB.ProtoEncoder(io), response)
        response_bytes = take!(io)

        # Add gRPC framing (5 bytes: 1 byte flags + 4 bytes length)
        framed_response = UInt8[]
        push!(framed_response, 0x00)  # No compression
        append!(framed_response, reinterpret(UInt8, [hton(UInt32(length(response_bytes)))]))
        append!(framed_response, response_bytes)

        return HTTP.Response(
            200,
            ["content-type" => "application/grpc", "grpc-status" => "0"],
            framed_response,
        )

    catch e
        @error "gRPC request failed" exception=(e, catch_backtrace())

        # Determine gRPC status code
        status = if e isa ArgumentError
            "3"  # INVALID_ARGUMENT
        else
            "2"  # UNKNOWN
        end

        return HTTP.Response(
            200,  # gRPC uses HTTP 200 even for errors
            ["grpc-status" => status, "grpc-message" => sprint(showerror, e)],
            "",
        )
    end
end

# Start gRPC server
function start_grpc_server(; host = "127.0.0.1", port = 9090)
    @info "Starting gRPC server" host=host port=port

    # Create HTTP/2 server for gRPC
    server = HTTP.serve!(
        handle_grpc_request,
        host,
        port;
        # gRPC requires HTTP/2
        http2 = true,
        # Disable HTTP/1.1 upgrade
        h2_upgrade = false,
    )

    GRPCServer(host, port, server, true)
end

# Stop gRPC server
function stop_grpc_server(server::GRPCServer)
    if server.running && !isnothing(server.server)
        close(server.server)
        server.running = false
        @info "gRPC server stopped"
    end
end

end # module
