# Models module

module Models

using UUIDs
using Dates
using RxInfer
using ...RxInferKServe: ModelInstance, ModelMetadata

# Include model-related files
include("registry.jl")
include("base.jl")

# Export main functionality
export ModelRegistry, GLOBAL_REGISTRY
export register_model, get_model, list_models
export create_model_instance, delete_model_instance, list_model_instances, cleanup_old_instances
export infer
export register_builtin_models

end # module