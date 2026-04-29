@testset "Scheduler" begin
    reset_kernel!()
    order = String[]

    create_task("low", () -> push!(order, "low"), 1)
    create_task("high", () -> push!(order, "high"), 10)
    create_task("deadline", () -> push!(order, "deadline"), 10; deadline_ms=5)

    ran = start_scheduler()
    @test [task.name for task in ran] == ["deadline", "high", "low"]
    @test order == ["deadline", "high", "low"]
    @test all(task.state == :completed for task in ran)

    reset_kernel!()
    count = Ref(0)
    create_task("periodic", () -> begin
        count[] += 1
        count[] >= 3 ? :done : yield_task()
    end, 7; repeat=true, period_ms=2)
    start_scheduler(; max_ticks=5, until_idle=false)
    @test count[] == 3
    @test get_task("periodic").run_count == 3
    @test task_state("periodic") == :completed

    reset_kernel!()
    create_task("shutdown", () -> (stop_scheduler(); :done), 1)
    @test length(start_scheduler(; max_ticks=10, until_idle=false)) == 1

    @test_throws InvalidStateError start_scheduler(; max_ticks=-1)
    @test_throws InvalidStateError tick!(-1)
end
