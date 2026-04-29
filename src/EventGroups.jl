mutable struct EventGroup
    name::String
    bits::UInt64
    waiters::Vector{String}
end

function create_event_group(name::AbstractString; initial_bits::Integer=0)
    name_s = _validate_name(name, :event_group)
    haskey(_KERNEL.event_groups, name_s) &&
        throw(DuplicateResourceError(:event_group, name_s))
    group = EventGroup(name_s, UInt64(initial_bits), String[])
    _KERNEL.event_groups[name_s] = group
    return group
end

function set_event_bits!(name::AbstractString, bits::Integer)
    group = _require_event_group(name)
    group.bits |= UInt64(bits)
    _wake_event_waiters!(group)
    record_event!(:event_group, "set"; metadata=Dict(:group => group.name, :bits => group.bits))
    return group.bits
end

function clear_event_bits!(name::AbstractString, bits::Integer)
    group = _require_event_group(name)
    group.bits &= ~UInt64(bits)
    return group.bits
end

get_event_bits(name::AbstractString) = _require_event_group(name).bits

function wait_event_bits(name::AbstractString, bits::Integer, task_name::AbstractString;
                         wait_all::Bool=false, clear_on_exit::Bool=false,
                         timeout_ms=nothing)
    group = _require_event_group(name)
    mask = UInt64(bits)
    matched = wait_all ? ((group.bits & mask) == mask) : ((group.bits & mask) != 0)
    if matched
        result = group.bits & mask
        clear_on_exit && clear_event_bits!(name, result)
        return result
    end
    task = _require_task(task_name)
    _push_unique!(group.waiters, task.name)
    _mark_task_blocked!(task, "event_group:$(group.name)", timeout_ms)
    task.metadata[:event_wait_mask] = mask
    task.metadata[:event_wait_all] = wait_all
    task.metadata[:event_clear_on_exit] = clear_on_exit
    return UInt64(0)
end

function _wake_event_waiters!(group::EventGroup)
    for task_name in copy(group.waiters)
        task = get_task(task_name)
        task === nothing && continue
        mask = get(task.metadata, :event_wait_mask, UInt64(0))
        wait_all = get(task.metadata, :event_wait_all, false)
        matched = wait_all ? ((group.bits & mask) == mask) : ((group.bits & mask) != 0)
        if matched
            _wake_task!(task)
            get(task.metadata, :event_clear_on_exit, false) && clear_event_bits!(group.name, group.bits & mask)
            filter!(name -> name != task.name, group.waiters)
        end
    end
    return group
end

function _require_event_group(name::AbstractString)
    group = get(_KERNEL.event_groups, String(name), nothing)
    group === nothing && throw(ResourceNotFoundError(:event_group, String(name)))
    return group
end
