function _ready_tasks()
    tasks = [task for task in values(_KERNEL.tasks)
             if task.state == TASK_READY && task.next_release_ms <= _KERNEL.clock_ms]
    sort!(tasks, by = task -> (-task.effective_priority,
                               _deadline_sort_key(task.deadline_ms),
                               task.created_at))
    return tasks
end

function schedule_once!()
    scheduler_can_dispatch() || return nothing
    release_periodic_tasks!()
    ready = _ready_tasks()
    isempty(ready) && return nothing
    task = first(ready)
    return _run_task!(task)
end

function _run_task!(task::RTTask)
    previous_task = _KERNEL.current_task
    record_event!(:scheduler, "dispatch"; metadata=Dict(:task => task.name))
    run_hooks(:task_switch, previous_task, task.name)
    _KERNEL.current_task = task.name
    task.state = TASK_RUNNING
    task.last_run_at = _KERNEL.clock_ms
    try
        result = task.action()
        task.last_result = result
        task.last_error = nothing
        task.run_count += 1
        task.stack_high_water_mark = max(0, task.stack_high_water_mark - 1)
        task.stack_high_water_mark == 0 && run_hooks(:stack_overflow, task)
        _check_deadline!(task)
        record_event!(:task, "completed_step"; metadata=Dict(:task => task.name,
                                                             :result => result))
        if result in (:stop, :done)
            task.state = TASK_COMPLETED
        elseif result == :yield || task.repeat
            if task.period_ms !== nothing
                task.next_release_ms = _KERNEL.clock_ms + task.period_ms
            elseif current_config().time_slicing
                _KERNEL.sequence += 1
                task.created_at = _KERNEL.sequence
            end
            task.state = TASK_READY
        else
            task.state = TASK_COMPLETED
        end
    catch err
        task.last_error = err
        task.state = TASK_FAILED
        log_error("task failed: $(task.name)"; metadata=Dict(:error => err))
        record_event!(:fault, "task_failed"; metadata=Dict(:task => task.name,
                                                           :error => err))
        handle_task_fault!(task.name)
    finally
        _KERNEL.current_task = nothing
        task.effective_priority = max(task.effective_priority, task.priority)
    end
    return task
end

function _check_deadline!(task::RTTask)
    contract = get_task_contract(task.name)
    contract === nothing && return false
    contract.deadline_ms === nothing && return false
    task.last_run_at === nothing && return false
    lateness = _KERNEL.clock_ms - task.last_run_at
    if lateness > contract.deadline_ms + contract.jitter_ms
        record_event!(:deadline, "miss"; metadata=Dict(:task => task.name,
                                                       :lateness_ms => lateness))
        return true
    end
    return false
end

function start_scheduler(; max_ticks::Integer=typemax(Int), tick_ms::Integer=1, until_idle::Bool=true)
    Int(max_ticks) >= 0 || throw(InvalidStateError("max_ticks must be non-negative"))
    Int(tick_ms) >= 0 || throw(InvalidStateError("tick_ms must be non-negative"))
    config = current_config()
    actual_tick_ms = config.tickless ? 0 : Int(tick_ms)
    _KERNEL.running = true
    ran = RTTask[]
    ticks = 0
    while _KERNEL.running && ticks < Int(max_ticks)
        task = schedule_once!()
        if task === nothing
            run_hooks(:idle, _KERNEL)
            process_deferred_interrupts!()
            process_daemon_commands!()
            if until_idle
                break
            end
        else
            push!(ran, task)
        end
        if config.tickless && task === nothing
            plan = plan_tickless_idle()
            plan.sleep_ms != typemax(Int) && tick!(plan.sleep_ms)
        else
            tick!(actual_tick_ms)
        end
        sample_resources!()
        process_deferred_interrupts!()
        process_daemon_commands!()
        ticks += 1
    end
    _KERNEL.running = false
    return ran
end

function stop_scheduler()
    _KERNEL.running = false
    record_event!(:scheduler, "stop")
    return _KERNEL
end
