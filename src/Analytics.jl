function event_counts()
    counts = Dict{Symbol,Int}()
    for event in _KERNEL.events
        counts[event.category] = get(counts, event.category, 0) + 1
    end
    return counts
end

function task_run_counts()
    counts = Dict{String,Int}()
    for task in values(_KERNEL.tasks)
        counts[task.name] = task.run_count
    end
    return counts
end

function analytics_summary()
    summary = Dict{Symbol,Any}()
    summary[:clock_ms] = _KERNEL.clock_ms
    summary[:task_count] = length(_KERNEL.tasks)
    summary[:ready_tasks] = length([task for task in values(_KERNEL.tasks) if task.state == TASK_READY])
    summary[:blocked_tasks] = length([task for task in values(_KERNEL.tasks) if task.state == TASK_BLOCKED])
    summary[:failed_tasks] = length([task for task in values(_KERNEL.tasks) if task.state == TASK_FAILED])
    summary[:events] = event_counts()
    summary[:task_runs] = task_run_counts()
    summary[:resource_latest] = latest_resources()
    _KERNEL.analytics[:last_summary] = summary
    return summary
end
