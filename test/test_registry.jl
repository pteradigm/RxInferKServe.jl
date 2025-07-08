using Test
using RxInferKServe
using RxInferKServe.Models
using RxInfer
using UUIDs
using Dates

# Define test models outside of testsets to avoid scoping issues
@model function test_model(y)
    θ ~ Beta(1.0, 1.0)
    for i in 1:length(y)
        y[i] ~ Bernoulli(θ)
    end
end

@model function model1(y)
    θ ~ Beta(1.0, 1.0)
    for i in 1:length(y)
        y[i] ~ Bernoulli(θ)
    end
end

@model function model2(y)
    μ ~ Normal(0.0, 1.0)
    for i in 1:length(y)
        y[i] ~ Normal(μ, 1.0)
    end
end

@testset "Model Registry" begin
    # Clear registry before tests
    empty!(GLOBAL_REGISTRY.models)
    empty!(GLOBAL_REGISTRY.instances)
    
    @testset "Model Registration" begin
        # Register the model
        register_model("test_model", test_model, 
            version="1.0.0", 
            description="Test model for unit tests")
        
        @test haskey(GLOBAL_REGISTRY.models, "test_model")
        @test GLOBAL_REGISTRY.models["test_model"]["metadata"].name == "test_model"
        @test GLOBAL_REGISTRY.models["test_model"]["metadata"].version == "1.0.0"
        @test GLOBAL_REGISTRY.models["test_model"]["metadata"].description == "Test model for unit tests"
        
        # Test overwriting warning
        @test_logs (:warn, r"Model test_model already registered") register_model("test_model", test_model)
    end
    
    @testset "Model Instance Creation" begin
        # Ensure test_model is registered
        if !haskey(GLOBAL_REGISTRY.models, "test_model")
            register_model("test_model", test_model)
        end
        
        # Create instance
        instance = create_model_instance("test_model")
        
        @test instance.model_name == "test_model"
        @test haskey(GLOBAL_REGISTRY.instances, instance.id)
        @test GLOBAL_REGISTRY.instances[instance.id] === instance
        
        # Test creating instance for non-existent model
        @test_throws ArgumentError create_model_instance("non_existent_model")
    end
    
    @testset "Model Instance Deletion" begin
        # Create an instance to delete
        instance = create_model_instance("test_model")
        instance_id = instance.id
        
        @test haskey(GLOBAL_REGISTRY.instances, instance_id)
        
        # Delete the instance
        deleted_instance = delete_model_instance(instance_id)
        
        @test deleted_instance.id == instance_id
        @test !haskey(GLOBAL_REGISTRY.instances, instance_id)
        
        # Test deleting non-existent instance
        @test_throws ArgumentError delete_model_instance(uuid4())
    end
    
    @testset "Get Model" begin
        model = get_model("test_model")
        @test !isnothing(model)
        @test haskey(model, "function")
        @test haskey(model, "metadata")
        
        # Test non-existent model
        @test isnothing(get_model("non_existent_model"))
    end
    
    @testset "List Models" begin
        # Clear and add some models
        empty!(GLOBAL_REGISTRY.models)
        
        register_model("model1", model1, version="1.0.0")
        register_model("model2", model2, version="2.0.0")
        
        models = list_models()
        
        @test length(models) == 2
        @test haskey(models, "model1")
        @test haskey(models, "model2")
        @test models["model1"].version == "1.0.0"
        @test models["model2"].version == "2.0.0"
    end
    
    @testset "Cleanup Old Instances" begin
        # Create some instances
        instance1 = create_model_instance("model1")
        instance2 = create_model_instance("model2")
        
        # Manually set last_used to old time for instance1
        instance1.last_used = now() - Hour(25)
        
        # Run cleanup
        cleaned = cleanup_old_instances(24)
        
        @test cleaned == 1
        @test !haskey(GLOBAL_REGISTRY.instances, instance1.id)
        @test haskey(GLOBAL_REGISTRY.instances, instance2.id)
    end
    
    # Clean up after tests
    empty!(GLOBAL_REGISTRY.models)
    empty!(GLOBAL_REGISTRY.instances)
end