struct TicklessPlan
    now_ms::Int
    wake_ms::Union{Nothing,Int}
    sleep_ms::Int
    reason::Symbol
end

function next_wakeup_ms()
    candidates = Int[]
    for task in values(_KERNEL.tasks)
        if task.state == TASK_READY
            push!(candidates, max(_KERNEL.clock_ms, task.next_release_ms))
        elseif task.state == TASK_BLOCKED && task.blocked_until_ms !== nothing
            push!(candidates, task.blocked_until_ms)
        end
    end
    for timer in values(_KERNEL.timers)
        timer.active && push!(candidates, timer.next_fire_ms)
    end
    for watchdog in values(_KERNEL.watchdogs)
        push!(candidates, watchdog.last_feed_ms + watchdog.timeout_ms)
    end
    isempty(candidates) && return nothing
    return minimum(candidates)
end

function plan_tickless_idle()
    ready_now = [task for task in values(_KERNEL.tasks)
                 if task.state == TASK_READY && task.next_release_ms <= _KERNEL.clock_ms]
    if !isempty(ready_now)
        return TicklessPlan(_KERNEL.clock_ms, _KERNEL.clock_ms, 0, :ready_task)
    end
    wake = next_wakeup_ms()
    wake === nothing && return TicklessPlan(_KERNEL.clock_ms, nothing, typemax(Int), :no_wakeup)
    sleep = max(0, wake - _KERNEL.clock_ms)
    return TicklessPlan(_KERNEL.clock_ms, wake, sleep, :scheduled_wakeup)
end
