mutable struct PeriodicJob
    name::String
    task_name::String
    period_ms::Int
    next_release_ms::Int
    enabled::Bool
end

function create_periodic_task(name::AbstractString, action::Function,
                              priority::Integer, period_ms::Integer;
                              deadline_ms=nothing, autostart::Bool=true,
                              metadata=Dict{Symbol,Any}())
    period_ms > 0 || throw(InvalidStateError("period_ms must be positive"))
    task = create_task(name, action, priority; deadline_ms=deadline_ms,
                       period_ms=period_ms, repeat=true,
                       autostart=autostart, metadata=metadata)
    job = PeriodicJob(task.name, task.name, Int(period_ms),
                      _KERNEL.clock_ms, autostart)
    _KERNEL.periodic_jobs[job.name] = job
    return job
end

function start_periodic_task!(name::AbstractString)
    job = _require_periodic_job(name)
    job.enabled = true
    job.next_release_ms = _KERNEL.clock_ms
    task = get_task(job.task_name)
    if task !== nothing && task.state == TASK_SUSPENDED
        task.state = TASK_READY
        task.next_release_ms = _KERNEL.clock_ms
    end
    record_event!(:periodic, "start"; metadata=Dict(:job => job.name))
    return job
end

function stop_periodic_task!(name::AbstractString)
    job = _require_periodic_job(name)
    job.enabled = false
    task = get_task(job.task_name)
    if task !== nothing && task.state == TASK_READY
        task.state = TASK_SUSPENDED
    end
    record_event!(:periodic, "stop"; metadata=Dict(:job => job.name))
    return job
end

function release_periodic_tasks!()
    released = String[]
    for job in values(_KERNEL.periodic_jobs)
        task = get_task(job.task_name)
        if job.enabled && task !== nothing && task.state == TASK_SUSPENDED &&
           job.next_release_ms <= _KERNEL.clock_ms
            task.state = TASK_READY
            task.next_release_ms = _KERNEL.clock_ms
            job.next_release_ms = _KERNEL.clock_ms + job.period_ms
            push!(released, task.name)
        end
    end
    return released
end

function _require_periodic_job(name::AbstractString)
    job = get(_KERNEL.periodic_jobs, String(name), nothing)
    job === nothing && throw(ResourceNotFoundError(:periodic_job, String(name)))
    return job
end
