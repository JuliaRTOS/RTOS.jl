mutable struct DeadlockGraph
    waits_for::Dict{String,String}
end

DeadlockGraph() = DeadlockGraph(Dict{String,String}())

function would_deadlock(graph::DeadlockGraph, waiter::AbstractString, owner::AbstractString)
    waiter_s = String(waiter)
    seen = Set{String}([waiter_s])
    cursor = String(owner)
    while true
        cursor in seen && return true
        push!(seen, cursor)
        haskey(graph.waits_for, cursor) || return false
        cursor = graph.waits_for[cursor]
    end
end

mutable struct Watchdog
    name::String
    timeout_ms::Int
    last_feed_ms::Int
    expired::Bool
    on_expire::Union{Nothing,Function}
end

function create_watchdog(name::AbstractString, timeout_ms::Integer; on_expire=nothing)
    name_s = _validate_name(name, :watchdog)
    haskey(_KERNEL.watchdogs, name_s) && throw(DuplicateResourceError(:watchdog, name_s))
    timeout_ms > 0 || throw(InvalidStateError("watchdog timeout must be positive"))
    watchdog = Watchdog(name_s, Int(timeout_ms), _KERNEL.clock_ms, false, on_expire)
    _KERNEL.watchdogs[watchdog.name] = watchdog
    return watchdog
end

function feed_watchdog(name::AbstractString)
    watchdog = _require_watchdog(name)
    watchdog.last_feed_ms = _KERNEL.clock_ms
    watchdog.expired = false
    return watchdog
end

watchdog_expired(name::AbstractString) = _require_watchdog(name).expired

function check_watchdogs!()
    expired = Watchdog[]
    for watchdog in values(_KERNEL.watchdogs)
        if !watchdog.expired && _KERNEL.clock_ms - watchdog.last_feed_ms >= watchdog.timeout_ms
            watchdog.expired = true
            push!(expired, watchdog)
            watchdog.on_expire !== nothing && watchdog.on_expire(watchdog)
            log_warn("watchdog expired: $(watchdog.name)")
        end
    end
    return expired
end

function _require_watchdog(name::AbstractString)
    watchdog = get(_KERNEL.watchdogs, String(name), nothing)
    watchdog === nothing && throw(ResourceNotFoundError(:watchdog, String(name)))
    return watchdog
end
