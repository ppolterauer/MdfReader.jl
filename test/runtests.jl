using mdfReader
using Test

@testset "mdfReader.jl" begin
    @test mdfReader.open("testfiles/test.mdf")
end
