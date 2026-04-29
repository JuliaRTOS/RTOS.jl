using Test
using Utils

@testset "Utility Tests" begin
    @test uptime() >= 0
    @test cpu_usage() >= 0
end
