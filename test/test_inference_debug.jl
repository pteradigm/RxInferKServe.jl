using RxInferKServe
using RxInferKServe.Models: register_builtin_models, get_model, create_model_instance, infer
using RxInfer

# Start simple - just test the model function
println("Testing beta_bernoulli model creation...")

# First register built-in models
register_builtin_models()
println("Built-in models registered")

# Get the model
model_def = get_model("beta_bernoulli")
if isnothing(model_def)
    error("Model not found!")
end

model_fn = model_def["function"]
println("Model function: ", model_fn)

# Test data
y_data = [1.0, 0.0, 1.0, 1.0, 0.0]

# Try to create the model 
println("\nTrying to create model with data...")
try
    # Use keyword argument
    model = model_fn(y = y_data)
    println("Model created successfully: ", typeof(model))
catch e
    println("Error creating model: ", e)
end

# Try inference through the Models module
println("\nTrying inference through Models module...")
try
    # First create an instance
    instance = create_model_instance("beta_bernoulli")
    println("Instance created: ", instance.id)

    # Now run inference
    data = Dict(:y => y_data)
    results, duration = RxInferKServe.Models.infer(instance.id, data; iterations = 10)
    println("Inference successful!")
    println("Results: ", results)
catch e
    println("Error during inference: ", e)
    println("Stacktrace:")
    for frame in stacktrace(catch_backtrace())
        println("  ", frame)
    end
end
