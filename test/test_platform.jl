@testset "RTOS config" begin
    reset_kernel!()
    config = RTOSConfig(; max_priorities=4, max_tasks=1, allow_dynamic_allocation=false,
                        allocation_policy=:static)
    @test isempty(validate_config(config))
    configure!(config)
    create_task("ok", () -> :done, 3)
    @test_throws CapacityError create_task("too_many", () -> :done, 1)
    create_allocator("heap", 8)
    @test_throws InvalidStateError rtos_malloc("heap", 1)

    bad = RTOSConfig(; deterministic_only=true, ml_in_critical_path=true)
    @test !isempty(validate_config(bad))
end

@testset "Tickless planning" begin
    reset_kernel!()
    configure!(RTOSConfig(; tickless=true))
    create_task("later", () -> :done, 1; autostart=false)
    resume_task("later")
    delay_task("later", 25)
    plan = plan_tickless_idle()
    @test plan.sleep_ms == 25
    @test plan.reason == :scheduled_wakeup
end

@testset "Contracts and schedulability" begin
    reset_kernel!()
    create_task("fast", () -> :done, 5)
    create_task("slow", () -> :done, 4)
    set_task_contract!("fast"; period_ms=10, deadline_ms=5, wcet_ms=2)
    set_task_contract!("slow"; period_ms=10, deadline_ms=3, wcet_ms=4)
    report = schedulability_report()
    @test report.utilization == 0.6
    @test !report.schedulable
    @test "slow WCET exceeds deadline" in report.problems
end

@testset "Security model" begin
    reset_kernel!()
    create_task("secure", () -> :done, 1; metadata=Dict(:privileged => true))
    @test !isempty(validate_security())
    grant_capability!("secure", "privileged")
    @test has_capability("secure", "privileged")
    @test isempty(validate_security())
    region = define_memory_region!("sram", 0, 1024; permissions=Set([:read, :write]))
    @test assign_region!("secure", "sram") === region
    revoke_capability!("secure", "privileged")
    @test !has_capability("secure", "privileged")
end

@testset "Trace and build plan" begin
    reset_kernel!()
    record_event!(:test, "hello")
    @test occursin("\"traceEvents\"", chrome_trace())

    board_started = Ref(false)
    register_port!("host"; cores=1)
    @test_throws DuplicateResourceError register_port!("host"; cores=1)
    board = register_board!("dev"; port="host", start=(_ -> (board_started[] = true)))
    @test_throws DuplicateResourceError register_board!("dev"; port="host")
    @test_throws ResourceNotFoundError register_board!("bad_board"; port="missing")
    @test current_board() === board
    start_board!("dev")
    @test board_started[]

    target = create_build_target("firmware", () -> 0; board="dev", artifact_kind=:executable)
    @test_throws DuplicateResourceError create_build_target("firmware", () -> 0)
    @test validate_build_target(target) == String[]
    plan = build_plan("firmware")
    @test plan.valid
    @test plan.board == "dev"

    bad = create_build_target("bad", () -> 0; board="missing")
    @test !build_plan("bad").valid
    @test_throws InvalidStateError build_target!("bad")
end
