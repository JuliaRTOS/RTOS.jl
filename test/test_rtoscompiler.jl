using Test
using RTOSCompiler

@testset "RTOS Compilation Tests" begin
    function sample_task()
        println("Executing compiled task")
    end
    compiled_code = compile_rtos(sample_task)
    @test compiled_code !== nothing
end
