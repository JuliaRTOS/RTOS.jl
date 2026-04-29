struct KernelObject
    kind::Symbol
    name::String
    state::Any
    metadata::Dict{Symbol,Any}
end

function kernel_registry()
    objects = KernelObject[]
    _append_registry!(objects, :task, _KERNEL.tasks)
    _append_registry!(objects, :queue, _KERNEL.queues)
    _append_registry!(objects, :mutex, _KERNEL.mutexes)
    _append_registry!(objects, :semaphore, _KERNEL.semaphores)
    _append_registry!(objects, :timer, _KERNEL.timers)
    _append_registry!(objects, :driver, _KERNEL.drivers)
    _append_registry!(objects, :event_group, _KERNEL.event_groups)
    _append_registry!(objects, :heap, _KERNEL.heaps)
    _append_registry!(objects, :network_interface, _KERNEL.network_interfaces)
    _append_registry!(objects, :ota_updater, _KERNEL.ota_updaters)
    return objects
end

function find_kernel_object(kind::Symbol, name::AbstractString)
    for object in kernel_registry()
        object.kind == kind && object.name == String(name) && return object
    end
    return nothing
end

function kernel_snapshot()
    counts = Dict{Symbol,Int}()
    for object in kernel_registry()
        counts[object.kind] = get(counts, object.kind, 0) + 1
    end
    return (clock_ms=_KERNEL.clock_ms, objects=counts,
            tasks=task_run_counts(), resources=latest_resources(),
            safety=validate_security())
end

function _append_registry!(objects::Vector{KernelObject}, kind::Symbol, source::Dict)
    for (name, value) in source
        push!(objects, KernelObject(kind, String(name), _object_state(value), Dict{Symbol,Any}()))
    end
    return objects
end

function _object_state(value)
    fields = fieldnames(typeof(value))
    :state in fields && return getfield(value, :state)
    :active in fields && return getfield(value, :active) ? :active : :inactive
    :enabled in fields && return getfield(value, :enabled) ? :enabled : :disabled
    return :registered
end
