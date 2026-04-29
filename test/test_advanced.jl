@testset "Ring buffer" begin
    buffer = RingBuffer{Int}(2)
    @test ring_empty(buffer)
    @test push_ring!(buffer, 1)
    @test push_ring!(buffer, 2)
    @test ring_full(buffer)
    @test !push_ring!(buffer, 3)
    @test pop_ring!(buffer) == 1
    @test peek_ring(buffer) == 2
    clear_ring!(buffer)
    @test ring_empty(buffer)

    overwrite = RingBuffer{Int}(2; overwrite=true)
    push_ring!(overwrite, 1)
    push_ring!(overwrite, 2)
    @test push_ring!(overwrite, 3)
    @test pop_ring!(overwrite) == 2
end

@testset "Observability and config" begin
    reset_kernel!()
    set_config!(:mode, :test)
    @test get_config(:mode) == :test
    @test config_snapshot()[:mode] == :test
    record_event!(:custom, "boot")
    @test event_counts()[:config] == 1
    @test event_counts()[:custom] == 1
    clear_events!()
    @test isempty(events())
end

@testset "Resource monitor, cache, and power" begin
    reset_kernel!()
    create_queue("q", 4)
    send_message("q", :msg)
    create_memory_pool("pool", 8, 2)
    allocate_block("pool")
    snapshot = sample_resources!()
    @test snapshot.queue_depth == 1
    @test snapshot.memory_used_blocks == 1
    @test latest_resources() === snapshot

    create_shared_cache("cache"; capacity=1)
    cache_put!("cache", :a, 1)
    @test cache_get("cache", :a) == 1
    cache_put!("cache", :b, 2)
    @test cache_get("cache", :a, :missing) == :missing
    @test cache_stats("cache").size == 1

    profile = create_power_profile("eco"; tick_ms=10, max_active_tasks=2)
    @test set_power_profile!("eco") === profile
    @test current_power_profile().name == "eco"
    @test get_config(:tick_ms) == 10
end

@testset "Task pools, periodic tasks, load balancing, faults, and ML hooks" begin
    reset_kernel!()
    order = String[]
    create_task("a", () -> push!(order, "a"), 1)
    create_task("b", () -> push!(order, "b"), 5)
    create_task("outside", () -> push!(order, "outside"), 10)

    pool = create_task_pool("pool"; max_concurrency=2)
    add_task_to_pool!("pool", "a")
    add_task_to_pool!("pool", "b")
    @test pool_tasks("pool") == ["a", "b"]
    ran = run_task_pool!("pool")
    @test [task.name for task in ran] == ["a", "b"]
    @test order == ["a", "b"]
    @test task_state("outside") == :ready

    @test first(balance_ready_tasks()).name == "outside"
    rebalance_priorities!(Dict("a" => 20))
    @test get_task("a").priority == 20

    reset_kernel!()
    register_fault_policy("default"; max_restarts=1)
    create_task("flaky", () -> error("boom"), 3)
    schedule_once!()
    @test task_state("flaky") == :ready
    schedule_once!()
    @test task_state("flaky") == :failed

    reset_kernel!()
    count = Ref(0)
    create_periodic_task("periodic", () -> (count[] += 1; count[] >= 2 ? :done : yield_task()), 5, 2)
    stop_periodic_task!("periodic")
    @test task_state("periodic") == :suspended
    start_periodic_task!("periodic")
    start_scheduler(; max_ticks=3, until_idle=false)
    @test count[] == 2

    register_ml_model("raise", _ -> Dict("periodic" => 9))
    @test_throws DuplicateResourceError register_ml_model("raise", _ -> Dict{String,Int}())
    adapt_scheduler!("raise")
    @test get_task("periodic").priority == 9
    register_ml_model("anomaly", _ -> true)
    @test !isempty(detect_anomaly("anomaly"))

    create_power_profile("fast"; tick_ms=1, max_active_tasks=4)
    register_ml_model("ops", _ -> MLDecision(; priorities=Dict("periodic" => 7),
                                             power_profile="fast",
                                             fault_risks=Dict("periodic" => 0.9),
                                             anomalies=["periodic risk"]))
    result = run_ml_cycle!("ops")
    @test get_task("periodic").priority == 7
    @test current_power_profile().name == "fast"
    @test result.risky_tasks == ["periodic"]
    @test result.anomalies == ["periodic risk"]
    @test predict_faults("ops"; threshold=0.8) == ["periodic"]
    @test haskey(ml_features(), :tasks)
end

@testset "Integration adapters" begin
    reset_kernel!()
    @test integration_available("StaticCompiler")
    @test_throws IntegrationUnavailableError require_integration("__DefinitelyMissingPackage__", "test")
    @test control_step((state, input) -> state + input, 1, 2) == 3
end
