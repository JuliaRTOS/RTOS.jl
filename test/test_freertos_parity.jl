@testset "Event groups" begin
    reset_kernel!()
    create_task("waiter", () -> nothing, 1)
    group = create_event_group("flags")
    @test get_event_bits("flags") == 0
    @test wait_event_bits("flags", 0x03, "waiter"; wait_all=true, timeout_ms=5) == 0
    @test task_state("waiter") == :blocked
    set_event_bits!("flags", 0x01)
    @test task_state("waiter") == :blocked
    set_event_bits!("flags", 0x02)
    @test task_state("waiter") == :ready
    @test group.bits == 0x03
    @test clear_event_bits!("flags", 0x01) == 0x02
end

@testset "Stream and message buffers" begin
    reset_kernel!()
    create_stream_buffer("rx", 4)
    @test stream_send!("rx", UInt8[1, 2, 3, 4, 5]) == 4
    @test stream_available("rx") == 4
    @test stream_receive!("rx", 2) == UInt8[1, 2]
    @test stream_available("rx") == 2

    create_message_buffer("msgs", 2)
    @test message_send!("msgs", UInt8[0xaa])
    @test message_send!("msgs", UInt8[0xbb, 0xcc])
    @test !message_send!("msgs", UInt8[0xdd])
    @test message_receive!("msgs") == UInt8[0xaa]
    @test message_available("msgs") == 1
end

@testset "Queue sets and ISR-safe APIs" begin
    reset_kernel!()
    create_queue("q", 2)
    create_binary_semaphore("sem"; available=false)
    create_message_buffer("mb", 2)
    create_queue_set("set")
    add_to_queue_set!("set", :queue, "q")
    add_to_queue_set!("set", :semaphore, "sem")
    add_to_queue_set!("set", :message_buffer, "mb")
    @test select_from_queue_set("set") === nothing

    @test send_message_from_isr("q", :hello)
    @test select_from_queue_set("set") == (kind=:queue, name="q")
    receive_message("q")
    give_semaphore_from_isr("sem")
    @test select_from_queue_set("set") == (kind=:semaphore, name="sem")

    create_task("notified", () -> nothing, 1)
    @test notify_task_from_isr("notified", 2) == 2
    ran = Ref(false)
    defer_from_isr!(() -> (ran[] = true))
    @test process_deferred_interrupts!() == 1
    @test ran[]
end

@testset "Hooks, timeouts, trace, and runtime stats" begin
    reset_kernel!()
    ticks = Int[]
    idles = Ref(0)
    switches = Tuple{Any,Any}[]
    malloc_failed = Ref(false)
    register_tick_hook!(now -> push!(ticks, now))
    register_idle_hook!(_ -> (idles[] += 1))
    register_task_switch_hook!((from, to) -> push!(switches, (from, to)))
    register_malloc_fail_hook!((_, _) -> (malloc_failed[] = true))

    create_task("blocked", () -> nothing, 1; autostart=false)
    resume_task("blocked")
    delay_task("blocked", 3)
    tick!(2)
    @test task_state("blocked") == :blocked
    tick!(1)
    @test task_state("blocked") == :ready
    @test ticks == [2, 3]

    create_task("run", () -> :done, 3)
    start_scheduler(; max_ticks=1)
    @test !isempty(switches)

    create_allocator("heap", 1)
    @test rtos_malloc("heap", 2) === nothing
    @test malloc_failed[]

    reset_kernel!()
    register_hook!(:idle, _ -> (idles[] += 1))
    start_scheduler(; max_ticks=1, until_idle=false)
    @test idles[] >= 1
    @test runtime_stats()[:trace_records] >= 1
    @test export_trace() isa String
end

@testset "Recursive mutex" begin
    reset_kernel!()
    create_task("owner", () -> nothing, 1)
    mutex = create_recursive_mutex("recursive")
    @test lock_mutex("recursive", "owner")
    @test lock_mutex("recursive", "owner")
    @test mutex.lock_count == 2
    @test unlock_mutex("recursive", "owner")
    @test mutex.lock_count == 1
    @test unlock_mutex("recursive", "owner")
    @test mutex.owner === nothing
end

@testset "Port, affinity, static init, and stack stats" begin
    reset_kernel!()
    port = register_port!("host"; cores=2, tick_rate_hz=1000)
    @test current_port() === port
    create_task("a", () -> :done, 1; core_affinity=[2], stack_size=16)
    assignments = assign_ready_tasks_to_cores()
    @test assignments[2] == "a"
    @test stack_stats("a").stack_size == 16

    q = MessageQueue("", 1, Any[], 0)
    init_queue!(q, "static_q", 2)
    @test send_message("static_q", :ok)

    m = RTOSMutex("", nothing, 0, false, String[], DeadlockGraph())
    init_mutex!(m, "static_m")
    @test lock_mutex("static_m", "a")

    timer = RTOSTimer("", 1, _ -> nothing, false, false, 0, 0)
    init_timer!(timer, "static_t", 5, _ -> nothing)
    @test !timer_active("static_t")

    group = EventGroup("", 0x00, String[])
    init_event_group!(group, "static_g"; initial_bits=0x04)
    @test get_event_bits("static_g") == 0x04
end
