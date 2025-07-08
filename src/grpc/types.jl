# KServe v2 Types and Data Structures

module KServeV2Types

using JSON3
using StructTypes
using Dates
using ProtoBuf
using ..kserve.v2: ModelInferRequest, ModelInferResponse, InferTensorContents
using ..kserve.v2: ModelMetadataRequest, ModelMetadataResponse
using ..kserve.v2: ServerLiveRequest, ServerLiveResponse, ServerReadyRequest, ServerReadyResponse
using ..kserve.v2: ModelReadyRequest, ModelReadyResponse, InferParameter
using ..kserve.v2: ServerMetadataRequest, ServerMetadataResponse

export InferenceRequest, InferenceResponse
export MetadataRequest, MetadataResponse
export convert_to_kserve_tensor, convert_from_kserve_tensor
export tensor_datatype, tensor_shape

# Re-export protobuf types
export ModelInferRequest, ModelInferResponse, InferTensorContents
export ModelMetadataRequest, ModelMetadataResponse
export ServerLiveRequest, ServerLiveResponse, ServerReadyRequest, ServerReadyResponse
export ModelReadyRequest, ModelReadyResponse

# REST API Types (JSON representations)
struct InferenceRequest
    id::Union{String,Nothing}
    inputs::Vector{Dict{String,Any}}
    outputs::Union{Vector{Dict{String,Any}},Nothing}
    parameters::Union{Dict{String,Any},Nothing}
end

struct InferenceResponse
    model_name::String
    model_version::Union{String,Nothing}
    id::String
    outputs::Vector{Dict{String,Any}}
    parameters::Union{Dict{String,Any},Nothing}
end

struct MetadataRequest
    name::String
    version::Union{String,Nothing}
end

struct MetadataResponse
    name::String
    versions::Vector{String}
    platform::String
    inputs::Vector{Dict{String,Any}}
    outputs::Vector{Dict{String,Any}}
end

# StructTypes for JSON serialization
StructTypes.StructType(::Type{InferenceRequest}) = StructTypes.Struct()
StructTypes.StructType(::Type{InferenceResponse}) = StructTypes.Struct()
StructTypes.StructType(::Type{MetadataRequest}) = StructTypes.Struct()
StructTypes.StructType(::Type{MetadataResponse}) = StructTypes.Struct()

# Datatype mappings between KServe and Julia
const DATATYPE_MAP = Dict(
    "BOOL" => Bool,
    "UINT8" => UInt8,
    "UINT16" => UInt16,
    "UINT32" => UInt32,
    "UINT64" => UInt64,
    "INT8" => Int8,
    "INT16" => Int16,
    "INT32" => Int32,
    "INT64" => Int64,
    "FP16" => Float16,
    "FP32" => Float32,
    "FP64" => Float64,
    "BYTES" => Vector{UInt8}
)

const JULIA_TO_DATATYPE = Dict(v => k for (k, v) in DATATYPE_MAP)

# Helper functions for tensor conversion
function tensor_datatype(T::Type)
    get(JULIA_TO_DATATYPE, T, "BYTES")
end

function tensor_shape(arr::AbstractArray)
    collect(size(arr))
end

# Convert Julia arrays to KServe tensor format
function convert_to_kserve_tensor(name::String, data::AbstractArray; parameters=nothing)
    datatype = tensor_datatype(eltype(data))
    shape = tensor_shape(data)
    
    # Flatten the array for transmission
    flat_data = vec(data)
    
    # Create the appropriate contents based on datatype
    if datatype == "BOOL"
        InferTensorContents(
            flat_data,
            Vector{Int32}(),
            Vector{Int64}(),
            Vector{UInt32}(),
            Vector{UInt64}(),
            Vector{Float32}(),
            Vector{Float64}(),
            Vector{Vector{UInt8}}()
        )
    elseif datatype in ["INT8", "INT16", "INT32"]
        InferTensorContents(
            Vector{Bool}(),
            convert(Vector{Int32}, flat_data),
            Vector{Int64}(),
            Vector{UInt32}(),
            Vector{UInt64}(),
            Vector{Float32}(),
            Vector{Float64}(),
            Vector{Vector{UInt8}}()
        )
    elseif datatype == "INT64"
        InferTensorContents(
            Vector{Bool}(),
            Vector{Int32}(),
            flat_data,
            Vector{UInt32}(),
            Vector{UInt64}(),
            Vector{Float32}(),
            Vector{Float64}(),
            Vector{Vector{UInt8}}()
        )
    elseif datatype in ["UINT8", "UINT16", "UINT32"]
        InferTensorContents(
            Vector{Bool}(),
            Vector{Int32}(),
            Vector{Int64}(),
            convert(Vector{UInt32}, flat_data),
            Vector{UInt64}(),
            Vector{Float32}(),
            Vector{Float64}(),
            Vector{Vector{UInt8}}()
        )
    elseif datatype == "UINT64"
        InferTensorContents(
            Vector{Bool}(),
            Vector{Int32}(),
            Vector{Int64}(),
            Vector{UInt32}(),
            flat_data,
            Vector{Float32}(),
            Vector{Float64}(),
            Vector{Vector{UInt8}}()
        )
    elseif datatype in ["FP16", "FP32"]
        InferTensorContents(
            Vector{Bool}(),
            Vector{Int32}(),
            Vector{Int64}(),
            Vector{UInt32}(),
            Vector{UInt64}(),
            convert(Vector{Float32}, flat_data),
            Vector{Float64}(),
            Vector{Vector{UInt8}}()
        )
    elseif datatype == "FP64"
        InferTensorContents(
            Vector{Bool}(),
            Vector{Int32}(),
            Vector{Int64}(),
            Vector{UInt32}(),
            Vector{UInt64}(),
            Vector{Float32}(),
            flat_data,
            Vector{Vector{UInt8}}()
        )
    else
        # Convert to bytes
        InferTensorContents(
            Vector{Bool}(),
            Vector{Int32}(),
            Vector{Int64}(),
            Vector{UInt32}(),
            Vector{UInt64}(),
            Vector{Float32}(),
            Vector{Float64}(),
            [Vector{UInt8}(string(x)) for x in flat_data]
        )
    end
end

# Convert KServe tensor to Julia array
function convert_from_kserve_tensor(tensor::InferTensorContents)
    # Extract the data based on which field is populated
    flat_data = if !isempty(tensor.bool_contents)
        tensor.bool_contents
    elseif !isempty(tensor.int_contents)
        tensor.int_contents
    elseif !isempty(tensor.int64_contents)
        tensor.int64_contents
    elseif !isempty(tensor.uint_contents)
        tensor.uint_contents
    elseif !isempty(tensor.uint64_contents)
        tensor.uint64_contents
    elseif !isempty(tensor.fp32_contents)
        tensor.fp32_contents
    elseif !isempty(tensor.fp64_contents)
        tensor.fp64_contents
    elseif !isempty(tensor.bytes_contents)
        tensor.bytes_contents
    else
        error("No data found in tensor contents")
    end
    
    # Return the flat data (shape information is in the parent InferInputTensor)
    return flat_data
end

# Convert REST JSON request to protobuf types
function json_to_protobuf_request(json_req::InferenceRequest, model_name::String, model_version::String="")
    inputs = InferTensorContents[]
    
    for input in json_req.inputs
        name = input["name"]
        datatype = input["datatype"]
        shape = input["shape"]
        data = input["data"]
        
        # Convert flat data array to appropriate type
        T = get(DATATYPE_MAP, datatype, Any)
        typed_data = convert(Vector{T}, data)
        reshaped_data = reshape(typed_data, tuple(shape...))
        
        push!(inputs, convert_to_kserve_tensor(name, reshaped_data))
    end
    
    ModelInferRequest(
        model_name=model_name,
        model_version=model_version,
        id=something(json_req.id, ""),
        inputs=inputs,
        parameters=json_req.parameters
    )
end

# Convert protobuf response to REST JSON
function protobuf_to_json_response(pb_resp::ModelInferResponse)
    outputs = Dict{String,Any}[]
    
    for output in pb_resp.outputs
        push!(outputs, Dict(
            "name" => output.name,
            "datatype" => output.datatype,
            "shape" => output.shape,
            "data" => vec(convert_from_kserve_tensor(output))
        ))
    end
    
    # Convert InferParameter dict to regular dict
    params = isnothing(pb_resp.parameters) ? nothing : Dict{String,Any}(
        k => v for (k, v) in pb_resp.parameters
    )
    
    InferenceResponse(
        pb_resp.model_name,
        pb_resp.model_version,
        pb_resp.id,
        outputs,
        params
    )
end

end # module