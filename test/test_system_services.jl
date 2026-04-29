@testset "Kernel registry and UX helpers" begin
    initialize_rtos!(; config=RTOSConfig(; max_tasks=4), port="host", board="dev")
    create_app_task("control", () -> :done; priority=3, period_ms=10,
                    deadline_ms=5, wcet_ms=2)
    @test find_kernel_object(:task, "control") !== nothing
    @test kernel_snapshot().objects[:task] == 1
    @test daemon_running()
    @test system_report().schedulability.schedulable
end

@testset "Daemon service" begin
    reset_kernel!()
    start_daemon!()
    ran = Ref(false)
    post_daemon_command!(:custom, () -> (ran[] = true))
    @test process_daemon_commands!() == 1
    @test ran[]
    stop_daemon!()
    @test !daemon_running()
end

@testset "Heap schemes" begin
    reset_kernel!()
    create_heap!("h1", :heap1, 8)
    a = heap_alloc!("h1", 4)
    @test a !== nothing
    @test heap_alloc!("h1", 5) === nothing
    @test_throws InvalidStateError heap_free!("h1", a)

    create_heap!("h4", :heap4, 8)
    b = heap_alloc!("h4", 6)
    @test b !== nothing
    @test heap_stats("h4").used == 6
    @test heap_free!("h4", b) == 0

    create_heap!("regions", :region, 0; regions=[("fast", 4), ("slow", 8)])
    c = heap_alloc!("regions", 6)
    @test c !== nothing
    @test heap_stats("regions").used["slow"] == 6
end

@testset "Task-local storage and safety profiles" begin
    reset_kernel!()
    configure!(RTOSConfig(; allow_dynamic_allocation=false, allocation_policy=:static))
    create_task("critical", () -> :done, 1)
    set_task_contract!("critical"; period_ms=10, deadline_ms=5, wcet_ms=1)
    set_task_local!("critical", :sensor, "imu")
    @test get_task_local("critical", :sensor) == "imu"
    @test delete_task_local!("critical", :sensor)

    create_safety_profile("strict"; require_memory_regions=true)
    @test !safety_report("strict").passed
    define_memory_region!("sram", 0, 1024)
    assign_region!("critical", "sram")
    @test safety_report("strict").passed
end

@testset "Network and OTA interfaces" begin
    reset_kernel!()
    sent = Any[]
    register_network_interface!("net";
                                send=(payload -> (push!(sent, payload); length(sent))),
                                receive=(() -> :packet),
                                status=(() -> :up))
    @test network_send!("net", :hello) == 1
    @test network_receive!("net") == :packet
    @test network_status("net") == :up

    register_ota_updater!("ota";
                          stage=(artifact -> (artifact=artifact, staged=true)),
                          verify=(staged -> staged.staged),
                          apply=(staged -> staged.artifact))
    staged = stage_update!("ota", "firmware.bin")
    @test staged.staged
    @test verify_update!("ota")
    @test apply_update!("ota") == "firmware.bin"
end
