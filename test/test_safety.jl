@testset "Safety" begin
    reset_kernel!()

    graph = DeadlockGraph()
    graph.waits_for["a"] = "b"
    graph.waits_for["b"] = "c"
    @test would_deadlock(graph, "c", "a")
    @test !would_deadlock(graph, "d", "a")

    expired_names = String[]
    create_watchdog("main", 50; on_expire=(wd -> push!(expired_names, wd.name)))
    @test_throws DuplicateResourceError create_watchdog("main", 50)
    @test_throws InvalidStateError create_watchdog("bad", 0)
    tick!(49)
    @test !watchdog_expired("main")
    tick!(1)
    @test watchdog_expired("main")
    @test expired_names == ["main"]
    feed_watchdog("main")
    @test !watchdog_expired("main")
end
