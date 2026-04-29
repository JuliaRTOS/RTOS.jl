using Test
using Drivers

@testset "Driver Tests" begin
    init_driver("test_driver")
    @test driver_status("test_driver") == "Active"

    shutdown_driver("test_driver")
    @test driver_status("test_driver") == "Inactive"
end
