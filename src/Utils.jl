function _to_int(value, label::AbstractString)
    try
        return Int(value)
    catch
        throw(InvalidStateError("$(label) must be convertible to Int"))
    end
end

function _positive_int(value, label::AbstractString)
    value_i = _to_int(value, label)
    value_i > 0 || throw(CapacityError("$(label) must be positive"))
    return value_i
end

function _nonnegative_int(value, label::AbstractString)
    value_i = _to_int(value, label)
    value_i >= 0 || throw(CapacityError("$(label) must be non-negative"))
    return value_i
end

function _optional_int(value, label::AbstractString; min_value=nothing)
    value === nothing && return nothing
    value_i = _to_int(value, label)
    if min_value !== nothing && value_i < Int(min_value)
        throw(InvalidStateError("$(label) must be at least $(min_value)"))
    end
    return value_i
end

function _validate_name(name::AbstractString, kind::Symbol)
    name_s = strip(String(name))
    isempty(name_s) && throw(InvalidStateError("$(kind) name must not be empty"))
    return name_s
end

function _validate_priority(priority::Integer)
    priority_i = Int(priority)
    priority_i < 0 && throw(InvalidStateError("priority must be non-negative"))
    return priority_i
end

function _clamp_priority(priority::Integer; min_priority::Integer=0, max_priority::Integer=255)
    return clamp(Int(priority), Int(min_priority), Int(max_priority))
end

_metadata_dict(metadata) = Dict{Symbol,Any}(metadata)

_deadline_sort_key(deadline_ms) =
    deadline_ms === nothing ? typemax(Int) : Int(deadline_ms)

_block_until(timeout_ms) =
    timeout_ms === nothing ? nothing : _KERNEL.clock_ms + Int(timeout_ms)

function _push_unique!(items::Vector{String}, item::String)
    item in items || push!(items, item)
    return items
end

function _mark_task_blocked!(task::RTTask, reason::AbstractString, timeout_ms=nothing)
    task.state = TASK_BLOCKED
    task.waiting_on = String(reason)
    task.blocked_until_ms = _block_until(timeout_ms)
    return task
end

function _wake_task!(task::RTTask)
    task.state = TASK_READY
    task.waiting_on = nothing
    task.blocked_until_ms = nothing
    return task
end

function Base.show(io::IO, task::RTTask)
    print(io, "RTTask(", task.name, ", priority=", task.priority,
          ", state=", task.state, ", runs=", task.run_count, ")")
end
