using Test
using RxInferKServe
# Import client functions that are not exported
using RxInferKServe: ready_check, client_list_models, get_model_metadata, run_inference

@testset "Client" begin
    # Start server on a random port
    port = 8080 + rand(1000:9000)
    server = nothing
    
    try
        # Start the server
        server = RxInferKServe.start_server(port=port, enable_grpc=false)
        sleep(1)  # Give server time to start
        
        # Create client
        client = RxInferClient("http://localhost:$port")
        
        @testset "Health Check" begin
            @test ready_check(client)["ready"] == true
        end
        
        @testset "List Models" begin
            response = client_list_models(client)
            models = response["models"]
            @test "beta_bernoulli" in models
            @test "linear_regression" in models
            @test "state_space" in models
        end
        
        @testset "Model Info" begin
            info = get_model_metadata(client, "beta_bernoulli")
            @test info["name"] == "beta_bernoulli"
            @test info["platform"] == "rxinfer"
            @test haskey(info, "versions")
            @test haskey(info, "inputs")
            @test haskey(info, "outputs")
        end
        
        @testset "Inference" begin
            # Test with beta_bernoulli model
            # KServe v2 format requires tensor inputs
            inputs = [
                Dict(
                    "name" => "y",
                    "datatype" => "FP64",
                    "shape" => [5],
                    "data" => [1.0, 0.0, 1.0, 1.0, 0.0]
                )
            ]
            parameters = Dict{String,Any}("iterations" => 10)
            
            results = run_inference(client, "beta_bernoulli", inputs; parameters=parameters)
            
            @test haskey(results, "model_name")
            @test results["model_name"] == "beta_bernoulli"
            @test haskey(results, "outputs")
            @test length(results["outputs"]) > 0
            
            # Check that posteriors are in the outputs
            posterior_output = findfirst(o -> o["name"] == "posteriors", results["outputs"])
            @test !isnothing(posterior_output)
        end
        
        @testset "Error Handling" begin
            # Test with non-existent model
            inputs_invalid = [Dict("name" => "x", "datatype" => "FP64", "shape" => [1], "data" => [1.0])]
            @test_throws Exception run_inference(client, "non_existent_model", inputs_invalid)
            
            # Test with empty inputs
            @test_throws Exception run_inference(client, "beta_bernoulli", [])
        end
        
    finally
        # Always stop the server
        if !isnothing(server)
            RxInferKServe.stop_server()
        end
    end
end