mutable struct FixedBlockPool
    name::String
    block_size::Int
    capacity::Int
    free_blocks::Vector{Vector{UInt8}}
    used::IdDict{Vector{UInt8},Bool}
end

function create_memory_pool(name::AbstractString, block_size::Integer, capacity::Integer)
    name_s = _validate_name(name, :memory_pool)
    haskey(_KERNEL.memory_pools, name_s) &&
        throw(DuplicateResourceError(:memory_pool, name_s))
    block_size > 0 || throw(CapacityError("block_size must be positive"))
    capacity > 0 || throw(CapacityError("capacity must be positive"))
    blocks = [zeros(UInt8, Int(block_size)) for _ in 1:Int(capacity)]
    pool = FixedBlockPool(name_s, Int(block_size), Int(capacity), blocks,
                          IdDict{Vector{UInt8},Bool}())
    _KERNEL.memory_pools[pool.name] = pool
    return pool
end

function allocate_block(name::AbstractString)
    pool = _require_pool(name)
    isempty(pool.free_blocks) && return nothing
    block = pop!(pool.free_blocks)
    pool.used[block] = true
    record_event!(:memory, "allocate_block"; metadata=Dict(:pool => pool.name))
    return block
end

function free_block!(name::AbstractString, block::Vector{UInt8})
    pool = _require_pool(name)
    haskey(pool.used, block) ||
        throw(InvalidStateError("block does not belong to pool or is already free"))
    delete!(pool.used, block)
    fill!(block, 0x00)
    push!(pool.free_blocks, block)
    record_event!(:memory, "free_block"; metadata=Dict(:pool => pool.name))
    return pool
end

function memory_stats(name::AbstractString)
    pool = _require_pool(name)
    return (capacity=pool.capacity, block_size=pool.block_size,
            free=length(pool.free_blocks), used=length(pool.used))
end

mutable struct DynamicAllocator
    name::String
    limit_bytes::Int
    used_bytes::Int
    allocations::IdDict{Vector{UInt8},Int}
end

function create_allocator(name::AbstractString, limit_bytes::Integer)
    name_s = _validate_name(name, :allocator)
    haskey(_KERNEL.allocators, name_s) && throw(DuplicateResourceError(:allocator, name_s))
    limit_bytes >= 0 || throw(CapacityError("allocator limit must be non-negative"))
    allocator = DynamicAllocator(name_s, Int(limit_bytes), 0,
                                 IdDict{Vector{UInt8},Int}())
    _KERNEL.allocators[allocator.name] = allocator
    return allocator
end

function rtos_malloc(name::AbstractString, bytes::Integer)
    current_config().allow_dynamic_allocation ||
        throw(InvalidStateError("dynamic allocation is disabled by RTOSConfig"))
    allocator = _require_allocator(name)
    size = Int(bytes)
    size >= 0 || throw(CapacityError("allocation size must be non-negative"))
    if allocator.used_bytes + size > allocator.limit_bytes
        run_hooks(:malloc_fail, allocator, size)
        record_event!(:memory, "malloc_fail"; metadata=Dict(:allocator => allocator.name,
                                                            :bytes => size))
        return nothing
    end
    block = zeros(UInt8, size)
    allocator.allocations[block] = size
    allocator.used_bytes += size
    record_event!(:memory, "malloc"; metadata=Dict(:allocator => allocator.name,
                                                   :bytes => size))
    return block
end

function rtos_free(name::AbstractString, block::Vector{UInt8})
    allocator = _require_allocator(name)
    haskey(allocator.allocations, block) || throw(ResourceNotFoundError(:allocation, "block"))
    allocator.used_bytes -= allocator.allocations[block]
    delete!(allocator.allocations, block)
    record_event!(:memory, "free"; metadata=Dict(:allocator => allocator.name))
    return allocator.used_bytes
end

function _require_pool(name::AbstractString)
    pool = get(_KERNEL.memory_pools, String(name), nothing)
    pool === nothing && throw(ResourceNotFoundError(:memory_pool, String(name)))
    return pool
end

function _require_allocator(name::AbstractString)
    allocator = get(_KERNEL.allocators, String(name), nothing)
    allocator === nothing && throw(ResourceNotFoundError(:allocator, String(name)))
    return allocator
end
