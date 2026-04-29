mutable struct TaskPool
    name::String
    members::Vector{String}
    max_concurrency::Int
end

function create_task_pool(name::AbstractString; max_concurrency::Integer=typemax(Int))
    name_s = _validate_name(name, :task_pool)
    haskey(_KERNEL.task_pools, name_s) && throw(DuplicateResourceError(:task_pool, name_s))
    max_concurrency > 0 || throw(CapacityError("max_concurrency must be positive"))
    pool = TaskPool(name_s, String[], Int(max_concurrency))
    _KERNEL.task_pools[name_s] = pool
    return pool
end

function add_task_to_pool!(pool_name::AbstractString, task_name::AbstractString)
    pool = _require_task_pool(pool_name)
    task = _require_task(task_name)
    task.name in pool.members || push!(pool.members, task.name)
    return pool
end

function remove_task_from_pool!(pool_name::AbstractString, task_name::AbstractString)
    pool = _require_task_pool(pool_name)
    filter!(name -> name != String(task_name), pool.members)
    return pool
end

pool_tasks(pool_name::AbstractString) = copy(_require_task_pool(pool_name).members)

function run_task_pool!(pool_name::AbstractString)
    pool = _require_task_pool(pool_name)
    ran = RTTask[]
    count = 0
    for task_name in copy(pool.members)
        count >= pool.max_concurrency && break
        task = get_task(task_name)
        if task !== nothing && task.state == TASK_READY && task.next_release_ms <= _KERNEL.clock_ms
            scheduled = _run_task!(task)
            scheduled !== nothing && push!(ran, scheduled)
            count += 1
        end
    end
    return ran
end

function _require_task_pool(name::AbstractString)
    pool = get(_KERNEL.task_pools, String(name), nothing)
    pool === nothing && throw(ResourceNotFoundError(:task_pool, String(name)))
    return pool
end
