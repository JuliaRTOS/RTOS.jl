mutable struct TaskContract
    task_name::String
    period_ms::Union{Nothing,Int}
    deadline_ms::Union{Nothing,Int}
    wcet_ms::Union{Nothing,Int}
    jitter_ms::Int
    criticality::Symbol
end

function set_task_contract!(task_name::AbstractString; period_ms=nothing,
                            deadline_ms=nothing, wcet_ms=nothing,
                            jitter_ms::Integer=0, criticality::Symbol=:normal)
    task = _require_task(task_name)
    jitter_ms >= 0 || throw(InvalidStateError("jitter_ms must be non-negative"))
    contract = TaskContract(task.name,
                            period_ms === nothing ? task.period_ms : Int(period_ms),
                            deadline_ms === nothing ? task.deadline_ms : Int(deadline_ms),
                            wcet_ms === nothing ? nothing : Int(wcet_ms),
                            Int(jitter_ms), criticality)
    _KERNEL.contracts[task.name] = contract
    return contract
end

get_task_contract(task_name::AbstractString) = get(_KERNEL.contracts, String(task_name), nothing)

function utilization()
    total = 0.0
    for contract in values(_KERNEL.contracts)
        if contract.wcet_ms !== nothing && contract.period_ms !== nothing && contract.period_ms > 0
            total += contract.wcet_ms / contract.period_ms
        end
    end
    return total
end

function schedulability_report()
    util = utilization()
    problems = String[]
    for contract in values(_KERNEL.contracts)
        if contract.wcet_ms !== nothing && contract.deadline_ms !== nothing &&
           contract.wcet_ms > contract.deadline_ms
            push!(problems, "$(contract.task_name) WCET exceeds deadline")
        end
    end
    util <= 1.0 || push!(problems, "total utilization exceeds one core")
    return (utilization=util, schedulable=isempty(problems), problems=problems)
end

function deadline_misses()
    misses = String[]
    for task in values(_KERNEL.tasks)
        contract = get_task_contract(task.name)
        if contract !== nothing && contract.deadline_ms !== nothing &&
           task.last_run_at !== nothing &&
           task.last_run_at - task.next_release_ms > contract.deadline_ms + contract.jitter_ms
            push!(misses, task.name)
        end
    end
    return misses
end
