@testset "Interrupts and drivers" begin
    reset_kernel!()

    count = Ref(0)
    register_interrupt("uart_rx", byte -> (count[] += byte))
    @test_throws DuplicateResourceError register_interrupt("uart_rx", _ -> nothing)
    @test_throws InvalidStateError register_interrupt("bad_irq", _ -> nothing; priority=-1)
    @test trigger_interrupt("uart_rx", 4) == 4
    disable_interrupt("uart_rx")
    @test trigger_interrupt("uart_rx", 4) === nothing
    @test count[] == 4

    storage = UInt8[]
    register_driver("uart";
                    read=(() -> isempty(storage) ? nothing : popfirst!(storage)),
                    write=(byte -> (push!(storage, byte); length(storage))),
                    control=(cmd -> cmd == :flush ? empty!(storage) : storage))
    @test_throws DuplicateResourceError register_driver("uart")
    @test write_device("uart", 0x42) == 1
    @test read_device("uart") == 0x42
    @test control_device("uart", :flush) == UInt8[]
end
