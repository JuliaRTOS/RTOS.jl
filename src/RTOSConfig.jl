mutable struct RTOSConfig
    max_priorities::Int
    tick_rate_hz::Int
    tickless::Bool
    allocation_policy::Symbol
    allow_dynamic_allocation::Bool
    deterministic_only::Bool
    ml_in_critical_path::Bool
    max_tasks::Int
    time_slicing::Bool
end

RTOSConfig(max_priorities::Integer, tick_rate_hz::Integer, tickless::Bool,
           allocation_policy::Symbol, allow_dynamic_allocation::Bool,
           deterministic_only::Bool, ml_in_critical_path::Bool,
           max_tasks::Integer) =
    RTOSConfig(Int(max_priorities), Int(tick_rate_hz), tickless,
               allocation_policy, allow_dynamic_allocation, deterministic_only,
               ml_in_critical_path, Int(max_tasks), true)

function RTOSConfig(; max_priorities::Integer=256, tick_rate_hz::Integer=1000,
                    tickless::Bool=false, allocation_policy::Symbol=:hybrid,
                    allow_dynamic_allocation::Bool=true,
                    deterministic_only::Bool=false,
                    ml_in_critical_path::Bool=false,
                    max_tasks::Integer=typemax(Int),
                    time_slicing::Bool=true)
    RTOSConfig(Int(max_priorities), Int(tick_rate_hz), tickless,
               allocation_policy, allow_dynamic_allocation, deterministic_only,
               ml_in_critical_path, Int(max_tasks), time_slicing)
end

function configure!(config::RTOSConfig)
    problems = validate_config(config)
    isempty(problems) || throw(InvalidStateError(join(problems, "; ")))
    _KERNEL.rtos_config = config
    set_config!(:tick_rate_hz, config.tick_rate_hz)
    set_config!(:tickless, config.tickless)
    set_config!(:allocation_policy, config.allocation_policy)
    set_config!(:time_slicing, config.time_slicing)
    return config
end

function current_config()
    _KERNEL.rtos_config === nothing && (_KERNEL.rtos_config = RTOSConfig())
    return _KERNEL.rtos_config
end

function validate_config(config::RTOSConfig=current_config())
    problems = String[]
    config.max_priorities > 0 || push!(problems, "max_priorities must be positive")
    config.tick_rate_hz > 0 || push!(problems, "tick_rate_hz must be positive")
    config.max_tasks > 0 || push!(problems, "max_tasks must be positive")
    config.allocation_policy in (:static, :dynamic, :hybrid) ||
        push!(problems, "allocation_policy must be :static, :dynamic, or :hybrid")
    if config.deterministic_only && config.ml_in_critical_path
        push!(problems, "deterministic_only forbids ML in the critical path")
    end
    if !config.allow_dynamic_allocation && config.allocation_policy == :dynamic
        push!(problems, "dynamic allocation policy requires allow_dynamic_allocation")
    end
    return problems
end
