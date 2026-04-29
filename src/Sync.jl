mutable struct RTOSMutex
    name::String
    owner::Union{Nothing,String}
    lock_count::Int
    recursive::Bool
    waiters::Vector{String}
    graph::DeadlockGraph
end

mutable struct CountingSemaphore
    name::String
    count::Int
    max_count::Int
    waiters::Vector{String}
end

const _GLOBAL_DEADLOCK_GRAPH = DeadlockGraph()

function create_mutex(name::AbstractString; recursive::Bool=false)
    name_s = _validate_name(name, :mutex)
    haskey(_KERNEL.mutexes, name_s) && throw(DuplicateResourceError(:mutex, name_s))
    mutex = RTOSMutex(name_s, nothing, 0, recursive, String[], DeadlockGraph())
    _KERNEL.mutexes[mutex.name] = mutex
    return mutex
end

create_recursive_mutex(name::AbstractString) = create_mutex(name; recursive=true)

function lock_mutex(name::AbstractString, task_name::AbstractString; block::Bool=false,
                    timeout_ms=nothing)
    mutex = _require_mutex(name)
    task = _require_task(task_name)
    if mutex.owner === nothing
        mutex.owner = task.name
        mutex.lock_count = 1
        return true
    elseif mutex.owner == task.name && mutex.recursive
        mutex.lock_count += 1
        return true
    end

    would_deadlock(_GLOBAL_DEADLOCK_GRAPH, task.name, mutex.owner) &&
        throw(InvalidStateError("deadlock prevented for $(task.name) on $(mutex.name)"))
    owner_task = get_task(mutex.owner)
    if owner_task !== nothing && owner_task.effective_priority < task.effective_priority
        owner_task.effective_priority = task.effective_priority
    end
    _push_unique!(mutex.waiters, task.name)
    mutex.graph.waits_for[task.name] = mutex.owner
    _GLOBAL_DEADLOCK_GRAPH.waits_for[task.name] = mutex.owner
    if block
        _mark_task_blocked!(task, mutex.name, timeout_ms)
    end
    return false
end

function unlock_mutex(name::AbstractString, task_name::Union{Nothing,AbstractString}=nothing)
    mutex = _require_mutex(name)
    mutex.owner === nothing && throw(InvalidStateError("mutex is not locked: $name"))
    if task_name !== nothing && mutex.owner != String(task_name)
        throw(InvalidStateError("task $(task_name) does not own mutex $name"))
    end
    owner_task = get_task(mutex.owner)
    mutex.lock_count -= 1
    mutex.lock_count > 0 && return true
    if owner_task !== nothing
        owner_task.effective_priority = owner_task.priority
    end
    delete!(mutex.graph.waits_for, mutex.owner)
    delete!(_GLOBAL_DEADLOCK_GRAPH.waits_for, mutex.owner)
    mutex.owner = nothing
    if !isempty(mutex.waiters)
        next_name = popfirst!(mutex.waiters)
        delete!(mutex.graph.waits_for, next_name)
        delete!(_GLOBAL_DEADLOCK_GRAPH.waits_for, next_name)
        next_task = get_task(next_name)
        if next_task !== nothing
            _wake_task!(next_task)
        end
        mutex.owner = next_name
        mutex.lock_count = 1
        _refresh_mutex_owner_priority!(mutex)
    end
    return true
end

function create_semaphore(name::AbstractString, count::Integer, max_count::Integer=count)
    name_s = _validate_name(name, :semaphore)
    haskey(_KERNEL.semaphores, name_s) &&
        throw(DuplicateResourceError(:semaphore, name_s))
    count_i = Int(count)
    max_i = Int(max_count)
    0 <= count_i <= max_i ||
        throw(CapacityError("semaphore count must be between 0 and max_count"))
    semaphore = CountingSemaphore(name_s, count_i, max_i, String[])
    _KERNEL.semaphores[semaphore.name] = semaphore
    return semaphore
end

create_binary_semaphore(name::AbstractString; available::Bool=true) =
    create_semaphore(name, available ? 1 : 0, 1)

create_counting_semaphore(name::AbstractString, count::Integer, max_count::Integer) =
    create_semaphore(name, count, max_count)

function take_semaphore(name::AbstractString, task_name::Union{Nothing,AbstractString}=nothing; block::Bool=false,
                        timeout_ms=nothing)
    semaphore = _require_semaphore(name)
    if semaphore.count > 0
        semaphore.count -= 1
        return true
    end
    if task_name !== nothing
        task = _require_task(task_name)
        _push_unique!(semaphore.waiters, task.name)
        if block
            _mark_task_blocked!(task, semaphore.name, timeout_ms)
        end
    end
    return false
end

function _refresh_mutex_owner_priority!(mutex::RTOSMutex)
    mutex.owner === nothing && return nothing
    owner_task = get_task(mutex.owner)
    owner_task === nothing && return nothing
    inherited = owner_task.priority
    for waiter in mutex.waiters
        waiter_task = get_task(waiter)
        waiter_task === nothing && continue
        inherited = max(inherited, waiter_task.effective_priority)
    end
    owner_task.effective_priority = inherited
    return owner_task.effective_priority
end

function _refresh_all_mutex_priorities!()
    for task in values(_KERNEL.tasks)
        task.effective_priority = task.priority
    end
    for mutex in values(_KERNEL.mutexes)
        _refresh_mutex_owner_priority!(mutex)
    end
    return nothing
end

function give_semaphore(name::AbstractString)
    semaphore = _require_semaphore(name)
    if !isempty(semaphore.waiters)
        next_name = popfirst!(semaphore.waiters)
        task = get_task(next_name)
        if task !== nothing
            _wake_task!(task)
        end
        return semaphore.count
    end
    semaphore.count = min(semaphore.max_count, semaphore.count + 1)
    return semaphore.count
end

function _require_mutex(name::AbstractString)
    mutex = get(_KERNEL.mutexes, String(name), nothing)
    mutex === nothing && throw(ResourceNotFoundError(:mutex, String(name)))
    return mutex
end

function _require_semaphore(name::AbstractString)
    semaphore = get(_KERNEL.semaphores, String(name), nothing)
    semaphore === nothing && throw(ResourceNotFoundError(:semaphore, String(name)))
    return semaphore
end
