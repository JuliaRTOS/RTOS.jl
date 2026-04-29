@testset "Static compiler integration" begin
    @test static_compile_available()
    @test_throws InvalidStateError compile_rtos(() -> 0; kind=:firmware_blob)
end
