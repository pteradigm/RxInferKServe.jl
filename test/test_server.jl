using Test
using RxInferKServe
using HTTP
using JSON3

@testset "Server" begin
    # Start server on a random port to avoid conflicts
    port = 8080 + rand(1000:9000)
    server = nothing

    try
        # Start the server
        server = RxInferKServe.start_server(port = port, enable_grpc = false)
        sleep(1)  # Give server time to start

        @testset "Health Endpoints" begin
            @testset "Live endpoint" begin
                response = HTTP.get("http://localhost:$port/v2/health/live")
                @test response.status == 200
                body = JSON3.read(response.body)
                @test body["live"] == true
            end

            @testset "Ready endpoint" begin
                response = HTTP.get("http://localhost:$port/v2/health/ready")
                @test response.status == 200
                body = JSON3.read(response.body)
                @test body["ready"] == true
            end
        end

        @testset "Models Endpoints" begin
            @testset "List models" begin
                response = HTTP.get("http://localhost:$port/v2/models")
                @test response.status == 200
                body = JSON3.read(response.body)
                @test haskey(body, "models")
                @test "beta_bernoulli" in body["models"]
                @test "linear_regression" in body["models"]
            end

            @testset "Model metadata" begin
                response = HTTP.get("http://localhost:$port/v2/models/beta_bernoulli")
                @test response.status == 200
                body = JSON3.read(response.body)
                @test body["name"] == "beta_bernoulli"
                @test body["platform"] == "rxinfer"
                @test haskey(body, "versions")
                @test haskey(body, "inputs")
                @test haskey(body, "outputs")
            end

            @testset "Model ready" begin
                response = HTTP.get("http://localhost:$port/v2/models/beta_bernoulli/ready")
                @test response.status == 200
                body = JSON3.read(response.body)
                @test body["ready"] == true
            end

            @testset "Non-existent model" begin
                response = HTTP.get(
                    "http://localhost:$port/v2/models/non_existent",
                    status_exception = false,
                )
                @test response.status == 404
                body = JSON3.read(response.body)
                @test haskey(body, "error")
            end
        end

        @testset "Inference Endpoint" begin
            request_body = Dict(
                "id" => "test-123",
                "inputs" => [
                    Dict(
                        "name" => "y",
                        "datatype" => "FP64",
                        "shape" => [5],
                        "data" => [1.0, 0.0, 1.0, 1.0, 0.0],
                    ),
                ],
                "parameters" => Dict("iterations" => 10),
            )

            response = HTTP.post(
                "http://localhost:$port/v2/models/beta_bernoulli/infer",
                ["Content-Type" => "application/json"],
                JSON3.write(request_body),
            )

            @test response.status == 200
            body = JSON3.read(response.body)
            @test body["model_name"] == "beta_bernoulli"
            @test body["id"] == "test-123"
            @test haskey(body, "outputs")
            @test length(body["outputs"]) > 0

            # Check that posteriors are included
            posterior_output = findfirst(o -> o["name"] == "posteriors", body["outputs"])
            @test !isnothing(posterior_output)
        end

        @testset "Error Handling" begin
            @testset "Invalid endpoint" begin
                response =
                    HTTP.get("http://localhost:$port/v2/invalid", status_exception = false)
                @test response.status == 404
            end

            @testset "Invalid inference request" begin
                request_body = Dict(
                    "inputs" => [],  # Empty inputs should cause an error
                )

                response = HTTP.post(
                    "http://localhost:$port/v2/models/beta_bernoulli/infer",
                    ["Content-Type" => "application/json"],
                    JSON3.write(request_body),
                    status_exception = false,
                )

                @test response.status == 500
                body = JSON3.read(response.body)
                @test haskey(body, "error")
            end
        end

    finally
        # Always stop the server
        if !isnothing(server)
            RxInferKServe.stop_server()
        end
    end
end
