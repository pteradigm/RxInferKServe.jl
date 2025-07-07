"""
Precompilation script for PackageCompiler
This script exercises the main functionality to ensure proper precompilation
"""

using RxInferMLServer
using RxInfer
using HTTP
using JSON3

# Initialize server components
println("Precompiling server components...")

# Create server config
config = RxInferMLServer.ServerConfig(
    host="127.0.0.1",
    port=8080,
    enable_auth=false,
    enable_cors=true
)

# Register models
RxInferMLServer.register_builtin_models()

# Create some model instances
println("Precompiling model operations...")

instance1 = RxInferMLServer.create_model_instance("beta_bernoulli")
instance2 = RxInferMLServer.create_model_instance("linear_regression")

# Serialize some distributions
using Distributions

println("Precompiling serialization...")

normal_dist = Normal(0.0, 1.0)
beta_dist = Beta(2.0, 3.0)
mvnormal_dist = MvNormal([0.0, 0.0], [1.0 0.0; 0.0 1.0])

json_normal = RxInferMLServer.distribution_to_json(normal_dist)
json_beta = RxInferMLServer.distribution_to_json(beta_dist)
json_mvnormal = RxInferMLServer.distribution_to_json(mvnormal_dist)

# Test JSON serialization
JSON3.write(json_normal)
JSON3.write(json_beta)
JSON3.write(json_mvnormal)

# Test inference
println("Precompiling inference...")

data = Dict(:y => [1, 0, 1, 1, 0])
results, duration = RxInferMLServer.infer(instance1.id, data)

# Clean up
RxInferMLServer.delete_model_instance(instance1.id)
RxInferMLServer.delete_model_instance(instance2.id)

println("Precompilation complete!")