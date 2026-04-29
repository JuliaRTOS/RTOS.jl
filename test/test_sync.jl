@testset "Synchronization" begin
    reset_kernel!()
    create_task("low", () -> nothing, 1)
    create_task("high", () -> nothing, 9)
    mutex = create_mutex("bus")

    @test lock_mutex("bus", "low")
    @test !lock_mutex("bus", "high"; block=true)
    @test !lock_mutex("bus", "high"; block=true)
    @test mutex.waiters == ["high"]
    @test get_task("low").effective_priority == 9
    @test task_state("high") == :blocked
    set_task_priority!("high", 12)
    @test get_task("low").effective_priority == 12

    @test unlock_mutex("bus", "low")
    @test mutex.owner == "high"
    @test task_state("high") == :ready

    create_binary_semaphore("ready"; available=false)
    @test !take_semaphore("ready", "low"; block=true)
    @test !take_semaphore("ready", "low"; block=true)
    @test length(RTOS.kernel_state().semaphores["ready"].waiters) == 1
    @test task_state("low") == :blocked
    give_semaphore("ready")
    @test task_state("low") == :ready

    sem = create_counting_semaphore("slots", 1, 2)
    @test take_semaphore("slots")
    @test sem.count == 0
    @test give_semaphore("slots") == 1

    reset_kernel!()
    create_task("a", () -> nothing, 1)
    create_task("b", () -> nothing, 1)
    create_mutex("m1")
    create_mutex("m2")
    @test lock_mutex("m1", "a")
    @test lock_mutex("m2", "b")
    @test !lock_mutex("m2", "a"; block=true)
    @test_throws InvalidStateError lock_mutex("m1", "b"; block=true)
end
