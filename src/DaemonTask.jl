mutable struct DaemonService
    name::String
    priority::Int
    running::Bool
    commands::Vector{Any}
    processed::Int
end

function start_daemon!(; name::AbstractString="rtos-daemon", priority::Integer=typemax(Int) - 1)
    if _KERNEL.daemon === nothing
        _KERNEL.daemon = DaemonService(String(name), Int(priority), true, Any[], 0)
    else
        _KERNEL.daemon.running = true
    end
    record_event!(:daemon, "start")
    return _KERNEL.daemon
end

function stop_daemon!()
    _KERNEL.daemon !== nothing && (_KERNEL.daemon.running = false)
    record_event!(:daemon, "stop")
    return _KERNEL.daemon
end

daemon_running() = _KERNEL.daemon !== nothing && _KERNEL.daemon.running

function post_daemon_command!(kind::Symbol, callback::Function, args...; kwargs...)
    daemon = _KERNEL.daemon === nothing ? start_daemon!() : _KERNEL.daemon
    push!(daemon.commands, (kind=kind, callback=callback, args=args, kwargs=kwargs))
    return length(daemon.commands)
end

function process_daemon_commands!(limit::Integer=typemax(Int))
    daemon = _KERNEL.daemon
    daemon === nothing && return 0
    processed = 0
    while daemon.running && processed < Int(limit) && !isempty(daemon.commands)
        command = popfirst!(daemon.commands)
        command.callback(command.args...; command.kwargs...)
        daemon.processed += 1
        processed += 1
        record_event!(:daemon, String(command.kind))
    end
    return processed
end
