@testset "Memory management" begin
    reset_kernel!()
    create_memory_pool("packets", 8, 2)
    @test_throws DuplicateResourceError create_memory_pool("packets", 8, 2)
    @test_throws CapacityError create_memory_pool("bad", 0, 2)

    a = allocate_block("packets")
    b = allocate_block("packets")
    @test a isa Vector{UInt8}
    @test b isa Vector{UInt8}
    @test allocate_block("packets") === nothing
    @test memory_stats("packets").used == 2

    a[1] = 0xff
    free_block!("packets", a)
    @test memory_stats("packets").free == 1
    c = allocate_block("packets")
    @test all(c .== 0x00)

    create_allocator("heap", 16)
    @test_throws DuplicateResourceError create_allocator("heap", 16)
    @test_throws CapacityError create_allocator("bad_heap", -1)
    h1 = rtos_malloc("heap", 10)
    @test h1 !== nothing
    @test rtos_malloc("heap", 7) === nothing
    @test rtos_free("heap", h1) == 0
end
