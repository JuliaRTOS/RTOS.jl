mutable struct FaultPolicy
    name::String
    max_restarts::Int
    restart_counts::Dict{String,Int}
    on_fault::Union{Nothing,Function}
end

function register_fault_policy(name::AbstractString; max_restarts::Integer=0,
                               on_fault=nothing)
    name_s = _validate_name(name, :fault_policy)
    haskey(_KERNEL.fault_policies, name_s) &&
        throw(DuplicateResourceError(:fault_policy, name_s))
    max_restarts >= 0 || throw(CapacityError("max_restarts must be non-negative"))
    policy = FaultPolicy(name_s, Int(max_restarts), Dict{String,Int}(), on_fault)
    _KERNEL.fault_policies[name_s] = policy
    return policy
end

function handle_task_fault!(task_name::AbstractString; policy::AbstractString="default")
    task = _require_task(task_name)
    fault_policy = get(_KERNEL.fault_policies, String(policy), nothing)
    fault_policy === nothing && return task
    count = get(fault_policy.restart_counts, task.name, 0)
    fault_policy.on_fault !== nothing && fault_policy.on_fault(task)
    if count < fault_policy.max_restarts
        fault_policy.restart_counts[task.name] = count + 1
        task.state = TASK_READY
        task.last_error = nothing
        record_event!(:fault, "restart"; metadata=Dict(:task => task.name))
    else
        record_event!(:fault, "failed"; metadata=Dict(:task => task.name))
    end
    return task
end
