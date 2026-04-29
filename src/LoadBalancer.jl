function balance_ready_tasks(; limit::Integer=typemax(Int))
    limit >= 0 || throw(CapacityError("limit must be non-negative"))
    ready = _ready_tasks()
    limit_i = min(Int(limit), length(ready))
    limit_i == 0 && return RTTask[]
    return ready[1:limit_i]
end

function rebalance_priorities!(weights::Dict{String,Int})
    for (name, priority) in weights
        haskey(_KERNEL.tasks, name) && set_task_priority!(name, priority)
    end
    record_event!(:scheduler, "rebalance"; metadata=Dict(:weights => weights))
    return _ready_tasks()
end
