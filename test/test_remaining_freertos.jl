@testset "Remaining FreeRTOS parity APIs" begin
    reset_kernel!()
    create_queue("control", 2)
    @test queue_spaces_available("control") == 2
    @test send_message("control", :a)
    @test peek_message("control") == :a
    @test queue_length("control") == 1
    @test receive_message("control") == :a

    create_task("rx", () -> :done, 1)
    @test receive_message("control"; default=:none, task_name="rx",
                          block=true, timeout_ms=10) == :none
    @test task_state("rx") == RTOS.TASK_BLOCKED
    @test send_message("control", :wake)
    @test task_state("rx") == RTOS.TASK_READY
    @test receive_message("control") == :wake

    @test send_message("control", 1)
    @test send_message("control", 2)
    @test queue_spaces_available("control") == 0
    reset_queue!("control")
    @test queue_length("control") == 0
    @test queue_spaces_available("control") == 2

    reset_kernel!()
    create_task("notify", () -> :done, 1)
    @test notify_task_value("notify", 0x01; action=:set_bits) == 0x01
    @test notify_task_value("notify", 0x04; action=:set_bits) == 0x05
    @test notify_task_value("notify", 9; action=:no_overwrite) == false
    @test take_notification("notify") == 0x05
    @test notify_task_value("notify", 9; action=:no_overwrite) == 9
    @test notify_task_value("notify", 3; action=:overwrite) == 3

    reset_kernel!()
    order = String[]
    create_task("a", () -> (push!(order, "a"); :yield), 2; repeat=true)
    create_task("b", () -> (push!(order, "b"); :yield), 2; repeat=true)
    schedule_once!()
    schedule_once!()
    @test order == ["a", "b"]

    suspend_scheduler!()
    @test scheduler_suspended()
    @test schedule_once!() === nothing
    resume_scheduler!()
    @test !scheduler_suspended()
    @test schedule_once!() !== nothing

    @test enter_critical!() == 1
    @test schedule_once!() === nothing
    @test exit_critical!() == 0

    reset_kernel!()
    fired = Ref(0)
    create_timer("sample", 10, _ -> fired[] += 1)
    start_timer("sample")
    tick!(5)
    reset_timer!("sample")
    tick!(5)
    @test fired[] == 0
    tick!(5)
    @test fired[] == 1
    @test timer_fire_count("sample") == 1
    change_timer_period!("sample", 2)
    tick!(2)
    @test fired[] == 2

    start_daemon!()
    pend_timer_command!("sample", :stop)
    process_daemon_commands!()
    @test !timer_active("sample")
    pend_timer_command!("sample", :change_period; period_ms=7)
    process_daemon_commands!()
    @test RTOS._require_timer("sample").period_ms == 7
end
