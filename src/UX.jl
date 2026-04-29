function initialize_rtos!(; config::RTOSConfig=RTOSConfig(), port=nothing, board=nothing,
                          start_daemon::Bool=true)
    reset_kernel!()
    configure!(config)
    port !== nothing && register_port!(String(port))
    if board !== nothing
        current_port() === nothing && register_port!("host")
        register_board!(String(board); port=current_port().name)
    end
    start_daemon && start_daemon!()
    return kernel_snapshot()
end

function create_app_task(name::AbstractString, action::Function; priority::Integer=1,
                         period_ms=nothing, deadline_ms=nothing, wcet_ms=nothing,
                         stack_size::Integer=1024, criticality::Symbol=:normal)
    task = create_task(name, action, priority; period_ms=period_ms,
                       deadline_ms=deadline_ms, repeat=period_ms !== nothing,
                       stack_size=stack_size)
    if period_ms !== nothing || deadline_ms !== nothing || wcet_ms !== nothing
        set_task_contract!(task.name; period_ms=period_ms, deadline_ms=deadline_ms,
                           wcet_ms=wcet_ms, criticality=criticality)
    end
    return task
end

run_rtos!(; max_ticks::Integer=typemax(Int), tick_ms::Integer=1,
          until_idle::Bool=true) =
    start_scheduler(; max_ticks=max_ticks, tick_ms=tick_ms, until_idle=until_idle)

function system_report()
    return (config=current_config(), registry=kernel_snapshot(),
            analytics=analytics_summary(), schedulability=schedulability_report(),
            security=validate_security(), safety_profiles=collect(keys(_KERNEL.safety_profiles)))
end
