@testset "Task lifecycle" begin
    reset_kernel!()

    task = create_task("worker", () -> :ok, 5; autostart=false)
    @test task_state("worker") == :suspended
    @test_throws DuplicateResourceError create_task("worker", () -> :duplicate, 1)
    @test_throws InvalidStateError create_task("", () -> nothing, 1)
    @test_throws InvalidStateError create_task("bad_priority", () -> nothing, -1)

    resume_task("worker")
    @test task_state("worker") == :ready

    notify_task("worker", 3)
    @test take_notification("worker"; clear=false) == 3
    @test take_notification("worker") == 2
    @test get_task("worker").notifications == 0

    suspend_task("worker")
    @test task_state("worker") == :suspended

    stop_task("worker")
    @test task_state("worker") == :stopped

    deleted = delete_task("worker")
    @test deleted.name == "worker"
    @test get_task("worker") === nothing
    @test_throws ResourceNotFoundError delete_task("worker")
end
