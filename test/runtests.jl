using RxInferKServe
using Test
using SafeTestsets
using Aqua

@testset "RxInferKServe.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(
            RxInferKServe;
            ambiguities = false,  # RxInfer has some ambiguities
            stale_deps = false,    # May have conditional dependencies
        )
    end

    @safetestset "Types" begin
        include("test_types.jl")
    end

    @safetestset "Serialization" begin
        include("test_serialization.jl")
    end

    @safetestset "Model Registry" begin
        include("test_registry.jl")
    end

    @safetestset "Server" begin
        include("test_server.jl")
    end

    @safetestset "Client" begin
        include("test_client.jl")
    end

    @safetestset "gRPC" begin
        include("test_grpc.jl")
    end
end
