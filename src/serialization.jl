# Serialization utilities for probabilistic distributions and RxInfer types

using JSON3
using StructTypes
using RxInfer
using Distributions

# Custom serialization for distributions
struct DistributionJSON
    type::String
    parameters::Dict{String,Any}
    dimensions::Union{Int,Nothing}
end

StructTypes.StructType(::Type{DistributionJSON}) = StructTypes.Struct()

# Convert distributions to JSON-serializable format
function distribution_to_json(d::Distribution)
    type_name = string(typeof(d))
    params = Dict{String,Any}()
    
    if d isa Normal
        params["mean"] = mean(d)
        params["std"] = std(d)
    elseif d isa MvNormal
        params["mean"] = mean(d)
        params["covariance"] = cov(d)
    elseif d isa Beta
        params["alpha"] = d.α
        params["beta"] = d.β
    elseif d isa Gamma
        params["shape"] = shape(d)
        params["rate"] = rate(d)
    elseif d isa Categorical
        params["probabilities"] = probs(d)
    else
        # Generic fallback
        params["params"] = params(d)
    end
    
    dims = d isa UnivariateDistribution ? nothing : length(d)
    
    return DistributionJSON(type_name, params, dims)
end

# Convert JSON back to distribution
function json_to_distribution(json::DistributionJSON)
    type_str = json.type
    params = json.parameters
    
    if occursin("Normal", type_str)
        if haskey(params, "covariance")
            return MvNormal(params["mean"], params["covariance"])
        else
            return Normal(params["mean"], params["std"])
        end
    elseif occursin("Beta", type_str)
        return Beta(params["alpha"], params["beta"])
    elseif occursin("Gamma", type_str)
        # Convert rate back to scale (scale = 1/rate)
        return Gamma(params["shape"], 1.0/params["rate"])
    elseif occursin("Categorical", type_str)
        return Categorical(params["probabilities"])
    else
        throw(ArgumentError("Unsupported distribution type: $type_str"))
    end
end

# Custom JSON3 integration
JSON3.write(d::Distribution) = JSON3.write(distribution_to_json(d))

# Serialize inference results
function serialize_inference_results(results::Dict)
    serialized = Dict{String,Any}()
    
    for (key, value) in results
        # Convert key to string if it's a Symbol
        str_key = key isa Symbol ? string(key) : key
        
        if value isa Distribution
            serialized[str_key] = distribution_to_json(value)
        elseif value isa AbstractArray{<:Distribution}
            serialized[str_key] = [distribution_to_json(d) for d in value]
        elseif value isa Dict
            # Recursively serialize any dict
            serialized[str_key] = serialize_inference_results(value)
        elseif value isa Message
            # Handle RxInfer messages
            serialized[str_key] = Dict(
                "type" => "Message",
                "data" => string(value)
            )
        else
            serialized[str_key] = value
        end
    end
    
    return serialized
end

# Deserialize inference requests
function deserialize_inference_data(data::Dict)
    deserialized = Dict{Symbol,Any}()
    
    for (key, value) in data
        sym_key = Symbol(key)
        
        if value isa Dict && haskey(value, "type") && haskey(value, "parameters")
            # Try to deserialize as distribution
            try
                deserialized[sym_key] = json_to_distribution(
                    DistributionJSON(value["type"], value["parameters"], get(value, "dimensions", nothing))
                )
            catch
                # If deserialization fails, keep as is
                deserialized[sym_key] = value
            end
        else
            deserialized[sym_key] = value
        end
    end
    
    return deserialized
end