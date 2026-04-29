using Test
using Interrupts

@testset "Interrupt Tests" begin
    test_triggered = false
    function interrupt_handler()
        global test_triggered
        test_triggered = true
    end

    register_interrupt("test_interrupt", interrupt_handler, 1)
    handle_interrupt("test_interrupt")
    
    @test test_triggered == true
end
