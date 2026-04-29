struct ResourceSnapshot
    time_ms::Int
    task_count::Int
    ready_count::Int
    blocked_count::Int
    failed_count::Int
    queue_depth::Int
    timer_count::Int
    memory_used_blocks::Int
    memory_free_blocks::Int
end

function sample_resources!(name::AbstractString="default")
    snapshot = ResourceSnapshot(
        _KERNEL.clock_ms,
        length(_KERNEL.tasks),
        length([task for task in values(_KERNEL.tasks) if task.state == TASK_READY]),
        length([task for task in values(_KERNEL.tasks) if task.state == TASK_BLOCKED]),
        length([task for task in values(_KERNEL.tasks) if task.state == TASK_FAILED]),
        _queue_depth(),
        length(_KERNEL.timers),
        _memory_used_blocks(),
        _memory_free_blocks(),
    )
    history = get!(_KERNEL.monitors, String(name), ResourceSnapshot[])
    push!(history, snapshot)
    record_event!(:resource, String(name); metadata=Dict(:snapshot => snapshot))
    return snapshot
end

function _queue_depth()
    total = 0
    for queue in values(_KERNEL.queues)
        total += length(queue.buffer)
    end
    return total
end

function _memory_used_blocks()
    total = 0
    for pool in values(_KERNEL.memory_pools)
        total += length(pool.used)
    end
    return total
end

function _memory_free_blocks()
    total = 0
    for pool in values(_KERNEL.memory_pools)
        total += length(pool.free_blocks)
    end
    return total
end

function resource_history(name::AbstractString="default")
    return copy(get(_KERNEL.monitors, String(name), ResourceSnapshot[]))
end

function latest_resources(name::AbstractString="default")
    history = get(_KERNEL.monitors, String(name), ResourceSnapshot[])
    isempty(history) && return nothing
    return history[end]
end
