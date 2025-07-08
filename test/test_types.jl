using Test
using RxInferKServe
using RxInferKServe: ModelMetadata, ModelInstance
using RxInferKServe.KServeV2: KServeV2Types
using JSON3
using Dates
using UUIDs

@testset "Core Types" begin
    @testset "ModelMetadata" begin
        metadata = ModelMetadata(
            "test_model",
            "1.0.0",
            "Test model description",
            now(),
            Dict{String,Any}("param1" => 1.0)
        )
        
        @test metadata.name == "test_model"
        @test metadata.version == "1.0.0"
        @test metadata.description == "Test model description"
        @test haskey(metadata.parameters, "param1")
        @test metadata.parameters["param1"] == 1.0
    end
    
    @testset "ModelInstance" begin
        metadata = ModelMetadata(
            "test_model",
            "1.0.0",
            "Test model description",
            now(),
            Dict{String,Any}()
        )
        
        instance_id = uuid4()
        instance = ModelInstance(
            instance_id,
            "test_model",
            metadata,
            Dict{String,Any}(),
            now(),
            now()
        )
        
        @test instance.id == instance_id
        @test instance.model_name == "test_model"
        @test instance.metadata.name == "test_model"
    end
end

@testset "KServe V2 Types" begin
    @testset "Tensor Conversion" begin
        # Test tensor datatype mapping
        @test RxInferKServe.KServeV2.KServeV2Types.tensor_datatype(Float64) == "FP64"
        @test RxInferKServe.KServeV2.KServeV2Types.tensor_datatype(Float32) == "FP32"
        @test RxInferKServe.KServeV2.KServeV2Types.tensor_datatype(Int64) == "INT64"
        @test RxInferKServe.KServeV2.KServeV2Types.tensor_datatype(Bool) == "BOOL"
        
        # Test tensor shape
        arr = rand(2, 3, 4)
        @test RxInferKServe.KServeV2.KServeV2Types.tensor_shape(arr) == [2, 3, 4]
    end
    
    @testset "REST API Types" begin
        # Test InferenceRequest
        req = RxInferKServe.KServeV2.KServeV2Types.InferenceRequest(
            "test-123",
            [
                Dict(
                    "name" => "input1",
                    "datatype" => "FP64",
                    "shape" => [2, 3],
                    "data" => [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
                )
            ],
            nothing,
            Dict("iterations" => 10)
        )
        
        @test req.id == "test-123"
        @test length(req.inputs) == 1
        @test req.inputs[1]["name"] == "input1"
        @test req.parameters["iterations"] == 10
    end
end