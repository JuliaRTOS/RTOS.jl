@testset "IPC queues" begin
    reset_kernel!()
    q = create_queue("telemetry", 2)
    @test_throws DuplicateResourceError create_queue("telemetry", 1)
    @test_throws CapacityError create_queue("bad", 0)

    @test send_message("telemetry", :a)
    @test send_message("telemetry", :b)
    @test !send_message("telemetry", :c)
    @test queue_length("telemetry") == 2
    @test receive_message("telemetry") == :a
    @test receive_message("telemetry") == :b
    @test receive_message("telemetry"; default=:empty) == :empty

    @test send_message("telemetry", 1)
    @test send_message("telemetry", 2)
    @test send_message("telemetry", 3; overwrite=true)
    @test q.dropped == 1
    @test receive_message("telemetry") == 2
end
