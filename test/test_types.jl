using RxInferMLServer
using Test
using Dates
using UUIDs
using JSON3

@testset "Type Definitions" begin
    @testset "ModelMetadata" begin
        metadata = RxInferMLServer.ModelMetadata(
            "test_model",
            "1.0.0",
            "Test description",
            now(),
            Dict("param1" => 1, "param2" => "value")
        )
        
        @test metadata.name == "test_model"
        @test metadata.version == "1.0.0"
        @test metadata.description == "Test description"
        @test isa(metadata.created_at, DateTime)
        @test metadata.parameters["param1"] == 1
    end
    
    @testset "ModelInstance" begin
        metadata = RxInferMLServer.ModelMetadata(
            "test_model", "1.0.0", "Test", now(), Dict()
        )
        
        instance = RxInferMLServer.ModelInstance(
            uuid4(),
            "test_model",
            metadata,
            Dict("state" => 1),
            now(),
            now()
        )
        
        @test isa(instance.id, UUID)
        @test instance.model_name == "test_model"
        @test instance.state["state"] == 1
    end
    
    @testset "ServerConfig" begin
        config = RxInferMLServer.ServerConfig()
        
        @test config.host == "127.0.0.1"
        @test config.port == 8080
        @test config.workers == 1
        @test config.enable_cors == true
        @test config.enable_auth == false
        
        # Custom config
        custom_config = RxInferMLServer.ServerConfig(
            host="0.0.0.0",
            port=9090,
            enable_auth=true,
            api_keys=["test-key"]
        )
        
        @test custom_config.host == "0.0.0.0"
        @test custom_config.port == 9090
        @test custom_config.enable_auth == true
        @test "test-key" in custom_config.api_keys
    end
    
    @testset "JSON Serialization" begin
        # Test that types can be serialized to JSON
        response = RxInferMLServer.HealthResponse(
            "healthy",
            "1.0.0",
            100.5,
            5,
            now()
        )
        
        json_str = JSON3.write(response)
        @test !isempty(json_str)
        
        # Test round-trip
        parsed = JSON3.read(json_str, RxInferMLServer.HealthResponse)
        @test parsed.status == response.status
        @test parsed.version == response.version
        @test parsed.models_loaded == response.models_loaded
    end
end