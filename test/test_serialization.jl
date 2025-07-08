using Test
using RxInferKServe
using RxInferKServe.Serialization: distribution_to_json, json_to_distribution, serialize_inference_results, deserialize_inference_data
using Distributions
using JSON3

@testset "Serialization" begin
    @testset "Distribution JSON Conversion" begin
        @testset "Normal Distribution" begin
            dist = Normal(0.0, 1.0)
            json_rep = distribution_to_json(dist)
            
            @test json_rep.type == "Normal{Float64}"
            @test json_rep.parameters["mean"] ≈ 0.0
            @test json_rep.parameters["std"] ≈ 1.0
            
            # Test round-trip
            reconstructed = json_to_distribution(json_rep)
            @test reconstructed isa Normal
            @test mean(reconstructed) ≈ 0.0
            @test std(reconstructed) ≈ 1.0
        end
        
        @testset "Beta Distribution" begin
            dist = Beta(2.0, 3.0)
            json_rep = distribution_to_json(dist)
            
            @test json_rep.type == "Beta{Float64}"
            @test json_rep.parameters["alpha"] ≈ 2.0
            @test json_rep.parameters["beta"] ≈ 3.0
            
            # Test round-trip
            reconstructed = json_to_distribution(json_rep)
            @test reconstructed isa Beta
            @test reconstructed.α ≈ 2.0
            @test reconstructed.β ≈ 3.0
        end
        
        @testset "Gamma Distribution" begin
            dist = Gamma(2.0, 3.0)
            json_rep = distribution_to_json(dist)
            
            @test json_rep.type == "Gamma{Float64}"
            @test json_rep.parameters["shape"] ≈ 2.0
            @test json_rep.parameters["rate"] ≈ 1/3.0  # Gamma in Julia uses shape/scale
            
            # Test round-trip
            reconstructed = json_to_distribution(json_rep)
            @test reconstructed isa Gamma
            @test shape(reconstructed) ≈ 2.0
            @test scale(reconstructed) ≈ 3.0
        end
    end
    
    @testset "Inference Results Serialization" begin
        results = Dict{Symbol,Any}(
            :posteriors => Dict{Symbol,Any}(
                :θ => Beta(3.0, 2.0),
                :μ => Normal(0.5, 0.1)
            ),
            :free_energy => -10.5,
            :iterations => 100
        )
        
        serialized = serialize_inference_results(results)
        
        @test haskey(serialized, "posteriors")
        @test haskey(serialized["posteriors"], "θ")
        @test haskey(serialized["posteriors"], "μ")
        @test serialized["posteriors"]["θ"].type == "Beta{Float64}"
        @test serialized["posteriors"]["μ"].type == "Normal{Float64}"
        @test serialized["free_energy"] ≈ -10.5
        @test serialized["iterations"] == 100
    end
    
    @testset "Inference Data Deserialization" begin
        data = Dict(
            "x" => [1.0, 2.0, 3.0],
            "y" => [2.1, 3.9, 6.2],
            "n_samples" => 100
        )
        
        deserialized = deserialize_inference_data(data)
        
        @test haskey(deserialized, :x)
        @test haskey(deserialized, :y)
        @test haskey(deserialized, :n_samples)
        @test deserialized[:x] == [1.0, 2.0, 3.0]
        @test deserialized[:y] == [2.1, 3.9, 6.2]
        @test deserialized[:n_samples] == 100
    end
end