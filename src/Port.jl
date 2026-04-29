mutable struct PortConfig
    name::String
    architecture::String
    cores::Int
    tick_rate_hz::Int
    metadata::Dict{Symbol,Any}
end

function register_port!(name::AbstractString; architecture::AbstractString="host",
                        cores::Integer=1, tick_rate_hz::Integer=1000,
                        metadata=Dict{Symbol,Any}())
    name_s = _validate_name(name, :port)
    haskey(_KERNEL.ports, name_s) && throw(DuplicateResourceError(:port, name_s))
    cores > 0 || throw(CapacityError("cores must be positive"))
    tick_rate_hz > 0 || throw(CapacityError("tick_rate_hz must be positive"))
    port = PortConfig(name_s, String(architecture), Int(cores), Int(tick_rate_hz),
                      _metadata_dict(metadata))
    _KERNEL.ports[name_s] = port
    set_config!(:port, name_s)
    return port
end

function current_port()
    name = get_config(:port, nothing)
    name === nothing && return nothing
    return get(_KERNEL.ports, String(name), nothing)
end

function set_core_count!(cores::Integer)
    cores > 0 || throw(CapacityError("cores must be positive"))
    port = current_port()
    port === nothing && (port = register_port!("host"; cores=cores))
    port.cores = Int(cores)
    return port
end

function set_task_affinity!(task_name::AbstractString, cores)
    task = _require_task(task_name)
    task.core_affinity = Int[Int(core) for core in cores]
    return task
end

function assign_ready_tasks_to_cores()
    port = current_port()
    core_count = port === nothing ? 1 : port.cores
    assignments = Dict{Int,Union{Nothing,String}}()
    ready = _ready_tasks()
    for core in 1:core_count
        assignments[core] = nothing
        for task in ready
            if task.assigned_core === nothing &&
               (isempty(task.core_affinity) || core in task.core_affinity)
                task.assigned_core = core
                assignments[core] = task.name
                break
            end
        end
    end
    return assignments
end
