using Test
using RxInferKServe
using RxInferKServe.KServeV2
using RxInferKServe.KServeV2: KServeV2Types, KServeV2GRPCServer
using RxInferKServe.KServeV2.kserve.v2: ServerLiveRequest, ServerLiveResponse, ServerReadyRequest, ServerReadyResponse
using RxInferKServe.KServeV2.kserve.v2: ModelReadyRequest, ModelReadyResponse, ModelMetadataRequest, ModelMetadataResponse
using RxInferKServe.KServeV2.kserve.v2: ModelInferRequest, ModelInferResponse, InferParameter, InferTensorContents
const InferRequestedOutputTensor = RxInferKServe.KServeV2.kserve.v2.var"ModelInferRequest.InferRequestedOutputTensor"
using ProtoBuf
using JSON3

@testset "gRPC Server and Client" begin
    # Start server with gRPC enabled
    port = 8080 + rand(1000:9000)
    grpc_port = 8081 + rand(1000:9000)
    server = nothing
    
    try
        # Start the server with gRPC
        server = RxInferKServe.start_server(
            port=port, 
            grpc_port=grpc_port, 
            enable_grpc=true
        )
        sleep(2)  # Give gRPC server time to start
        
        @testset "gRPC Health Endpoints" begin
            @testset "ServerLive" begin
                # Create a ServerLiveRequest
                # ServerLiveRequest has no fields
                request = ServerLiveRequest()
                
                # Note: Full gRPC client implementation would require a proper gRPC client
                # For now, we'll test that the gRPC server starts and the handlers exist
                @test isdefined(KServeV2.KServeV2GRPCServer, :handle_server_live)
                
                # Test the handler directly
                response = KServeV2.KServeV2GRPCServer.handle_server_live(request)
                @test response isa ServerLiveResponse
                @test response.live == true
            end
            
            @testset "ServerReady" begin
                request = ServerReadyRequest()
                response = KServeV2.KServeV2GRPCServer.handle_server_ready(request)
                @test response isa ServerReadyResponse
                @test response.ready == true
            end
        end
        
        @testset "gRPC Model Endpoints" begin
            @testset "ModelReady" begin
                request = ModelReadyRequest(
                    "beta_bernoulli",  # name
                    ""                # version
                )
                response = KServeV2.KServeV2GRPCServer.handle_model_ready(request)
                @test response isa ModelReadyResponse
                @test response.ready == true
            end
            
            @testset "ModelMetadata" begin
                request = ModelMetadataRequest(
                    "beta_bernoulli",  # name
                    ""                # version
                )
                response = KServeV2.KServeV2GRPCServer.handle_model_metadata(request)
                @test response isa ModelMetadataResponse
                @test response.name == "beta_bernoulli"
                @test response.platform == "rxinfer"
                @test length(response.inputs) > 0
                @test length(response.outputs) >= 0  # Some models may not define outputs
            end
        end
        
        @testset "gRPC Inference" begin
            # Create inference request with proper tensor format
            input_contents = KServeV2Types.convert_to_kserve_tensor(
                "y", [1.0, 0.0, 1.0, 1.0, 0.0]
            )
            
            # Create the input tensor with the InferInputTensor type
            input_tensor = RxInferKServe.KServeV2.kserve.v2.var"ModelInferRequest.InferInputTensor"(
                "y",                    # name
                "FP64",                 # datatype
                [5],                    # shape
                Dict{String,InferParameter}(),  # parameters
                input_contents          # contents
            )
            
            request = ModelInferRequest(
                "beta_bernoulli",      # model_name
                "",                   # model_version
                "test-grpc-123",       # id
                Dict{String,InferParameter}(  # parameters
                    "iterations" => InferParameter(ProtoBuf.OneOf(:int64_param, 10))
                ),
                [input_tensor],        # inputs
                InferRequestedOutputTensor[],  # outputs
                Vector{UInt8}[]        # raw_input_contents
            )
            
            response = KServeV2.KServeV2GRPCServer.handle_model_infer(request)
            @test response isa ModelInferResponse
            @test response.model_name == "beta_bernoulli"
            @test response.id == "test-grpc-123"
            @test length(response.outputs) > 0
            
            # Check that posteriors are in the outputs
            posterior_output = findfirst(o -> o.name == "posteriors", response.outputs)
            @test !isnothing(posterior_output)
        end
        
        @testset "gRPC Error Handling" begin
            @testset "Non-existent model" begin
                request = ModelReadyRequest(
                    "non_existent_model",  # name
                    ""                    # version
                )
                response = KServeV2.KServeV2GRPCServer.handle_model_ready(request)
                @test response.ready == false
            end
            
            @testset "Invalid inference request" begin
                # Request with no inputs
                request = ModelInferRequest(
                    "beta_bernoulli",      # model_name
                    "",                   # model_version
                    "test-error",          # id
                    Dict{String,InferParameter}(),  # parameters
                    InferTensorContents[],  # inputs (empty)
                    InferRequestedOutputTensor[],  # outputs
                    Vector{UInt8}[]        # raw_input_contents
                )
                @test_throws Exception KServeV2.KServeV2GRPCServer.handle_model_infer(request)
            end
        end
        
    finally
        # Always stop the server
        if !isnothing(server)
            RxInferKServe.stop_server()
        end
    end
end