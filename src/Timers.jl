mutable struct RTOSTimer
    name::String
    period_ms::Int
    callback::Function
    oneshot::Bool
    active::Bool
    next_fire_ms::Int
    fire_count::Int
end

function create_timer(name::AbstractString, period_ms::Integer, callback::Function; oneshot::Bool=false, autostart::Bool=false)
    name_s = _validate_name(name, :timer)
    haskey(_KERNEL.timers, name_s) && throw(DuplicateResourceError(:timer, name_s))
    period_i = _to_int(period_ms, "timer period")
    period_i > 0 || throw(InvalidStateError("timer period must be positive"))
    timer = RTOSTimer(name_s, period_i, callback, oneshot, false, 0, 0)
    _KERNEL.timers[timer.name] = timer
    autostart && start_timer(timer.name)
    return timer
end

function start_timer(name::AbstractString)
    timer = _require_timer(name)
    timer.active = true
    timer.next_fire_ms = _KERNEL.clock_ms + timer.period_ms
    return timer
end

function stop_timer(name::AbstractString)
    timer = _require_timer(name)
    timer.active = false
    return timer
end

timer_active(name::AbstractString) = _require_timer(name).active
timer_fire_count(name::AbstractString) = _require_timer(name).fire_count

function reset_timer!(name::AbstractString)
    timer = _require_timer(name)
    timer.active = true
    timer.next_fire_ms = _KERNEL.clock_ms + timer.period_ms
    return timer
end

function change_timer_period!(name::AbstractString, period_ms::Integer; reset::Bool=true)
    period_i = _to_int(period_ms, "timer period")
    period_i > 0 || throw(InvalidStateError("timer period must be positive"))
    timer = _require_timer(name)
    timer.period_ms = period_i
    reset && (timer.next_fire_ms = _KERNEL.clock_ms + timer.period_ms)
    return timer
end

function pend_timer_command!(name::AbstractString, command::Symbol; period_ms=nothing)
    if command == :start
        return post_daemon_command!(Symbol("timer_start_", String(name)),
                                    () -> start_timer(name))
    elseif command == :stop
        return post_daemon_command!(Symbol("timer_stop_", String(name)),
                                    () -> stop_timer(name))
    elseif command == :reset
        return post_daemon_command!(Symbol("timer_reset_", String(name)),
                                    () -> reset_timer!(name))
    elseif command == :change_period
        period_ms === nothing &&
            throw(InvalidStateError("period_ms is required for :change_period"))
        return post_daemon_command!(Symbol("timer_change_", String(name)),
                                    () -> change_timer_period!(name, period_ms))
    end
    throw(InvalidStateError("unsupported timer command: $(command)"))
end

function tick!(ms::Integer=1)
    ms_i = _to_int(ms, "tick duration")
    ms_i >= 0 || throw(InvalidStateError("tick duration must be non-negative"))
    _KERNEL.clock_ms += ms_i
    run_hooks(:tick, _KERNEL.clock_ms)
    _expire_blocked_tasks!()
    fired = RTOSTimer[]
    for timer in values(_KERNEL.timers)
        while timer.active && _KERNEL.clock_ms >= timer.next_fire_ms
            timer.fire_count += 1
            push!(fired, timer)
            record_event!(:timer, "fire"; metadata=Dict(:timer => timer.name,
                                                        :fire_count => timer.fire_count))
            timer.callback(timer)
            if timer.oneshot
                timer.active = false
            else
                timer.next_fire_ms += timer.period_ms
            end
        end
    end
    check_watchdogs!()
    return fired
end

function _expire_blocked_tasks!()
    for task in values(_KERNEL.tasks)
        if task.state == TASK_BLOCKED && task.blocked_until_ms !== nothing &&
           _KERNEL.clock_ms >= task.blocked_until_ms
            _wake_task!(task)
            record_event!(:timeout, "task_ready"; metadata=Dict(:task => task.name))
        end
    end
    return nothing
end

function _require_timer(name::AbstractString)
    timer = get(_KERNEL.timers, String(name), nothing)
    timer === nothing && throw(ResourceNotFoundError(:timer, String(name)))
    return timer
end
