@testset "Timers" begin
    reset_kernel!()
    fired = Ref(0)

    create_timer("heartbeat", 10, _ -> fired[] += 1; autostart=true)
    @test_throws DuplicateResourceError create_timer("heartbeat", 10, _ -> nothing)
    @test_throws InvalidStateError create_timer("bad", 0, _ -> nothing)
    tick!(9)
    @test fired[] == 0
    tick!(1)
    @test fired[] == 1
    tick!(20)
    @test fired[] == 3

    create_timer("once", 5, _ -> fired[] += 10; oneshot=true, autostart=true)
    tick!(5)
    @test fired[] == 13
    @test !timer_active("once")
end
