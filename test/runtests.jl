using CMark
using Test

@testset "CMark.jl" begin
    # Write your own tests here.
    @test CMark.cmark_version() == 7424
    @test CMark.cmark_version_string() == "0.29.0"
end
