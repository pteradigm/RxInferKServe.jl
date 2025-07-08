"""
Precompilation script for PackageCompiler
This script exercises the main functionality to ensure proper precompilation
"""

using RxInferKServe
using RxInfer
using HTTP
using JSON3

# Initialize server components
println("Precompiling server components...")

# Create server config
config = RxInferKServe.ServerConfig(
    host="127.0.0.1",
    port=8080,
    enable_auth=false,
    enable_cors=true
)

# Register models
RxInferKServe.register_builtin_models()

# Create some model instances
println("Precompiling model operations...")

instance1 = RxInferKServe.create_model_instance("beta_bernoulli")
instance2 = RxInferKServe.create_model_instance("linear_regression")

# Serialize some distributions
using Distributions

println("Precompiling serialization...")

normal_dist = Normal(0.0, 1.0)
beta_dist = Beta(2.0, 3.0)
mvnormal_dist = MvNormal([0.0, 0.0], [1.0 0.0; 0.0 1.0])

json_normal = RxInferKServe.distribution_to_json(normal_dist)
json_beta = RxInferKServe.distribution_to_json(beta_dist)
json_mvnormal = RxInferKServe.distribution_to_json(mvnormal_dist)

# Test JSON serialization
JSON3.write(json_normal)
JSON3.write(json_beta)
JSON3.write(json_mvnormal)

# Test inference
println("Precompiling inference...")

data = Dict(:y => [1, 0, 1, 1, 0])
results, duration = RxInferKServe.infer(instance1.id, data)

# Clean up
RxInferKServe.delete_model_instance(instance1.id)
RxInferKServe.delete_model_instance(instance2.id)

println("Precompilation complete!")