mutable struct QueueSet
    name::String
    members::Vector{Tuple{Symbol,String}}
end

function create_queue_set(name::AbstractString)
    name_s = _validate_name(name, :queue_set)
    haskey(_KERNEL.queue_sets, name_s) && throw(DuplicateResourceError(:queue_set, name_s))
    set = QueueSet(name_s, Tuple{Symbol,String}[])
    _KERNEL.queue_sets[name_s] = set
    return set
end

function add_to_queue_set!(set_name::AbstractString, kind::Symbol, member_name::AbstractString)
    set = _require_queue_set(set_name)
    member = (kind, String(member_name))
    member in set.members || push!(set.members, member)
    return set
end

function remove_from_queue_set!(set_name::AbstractString, kind::Symbol, member_name::AbstractString)
    set = _require_queue_set(set_name)
    member = (kind, String(member_name))
    filter!(item -> item != member, set.members)
    return set
end

function select_from_queue_set(set_name::AbstractString)
    set = _require_queue_set(set_name)
    for (kind, name) in set.members
        if kind == :queue && haskey(_KERNEL.queues, name) && queue_length(name) > 0
            return (kind=kind, name=name)
        elseif kind == :semaphore && haskey(_KERNEL.semaphores, name) && _KERNEL.semaphores[name].count > 0
            return (kind=kind, name=name)
        elseif kind == :message_buffer && haskey(_KERNEL.message_buffers, name) && message_available(name) > 0
            return (kind=kind, name=name)
        elseif kind == :stream_buffer && haskey(_KERNEL.stream_buffers, name) && stream_available(name) > 0
            return (kind=kind, name=name)
        end
    end
    return nothing
end

function _require_queue_set(name::AbstractString)
    set = get(_KERNEL.queue_sets, String(name), nothing)
    set === nothing && throw(ResourceNotFoundError(:queue_set, String(name)))
    return set
end
