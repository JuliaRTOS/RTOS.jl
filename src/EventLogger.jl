struct EventRecord
    time_ms::Int
    category::Symbol
    name::String
    task::Union{Nothing,String}
    metadata::Dict{Symbol,Any}
end

function record_event!(category::Symbol, name::AbstractString;
                       metadata=Dict{Symbol,Any}())
    event = EventRecord(_KERNEL.clock_ms, category, String(name),
                        _KERNEL.current_task, _metadata_dict(metadata))
    push!(_KERNEL.events, event)
    push!(_KERNEL.trace, event)
    return event
end

function events(category::Union{Nothing,Symbol}=nothing)
    category === nothing && return copy(_KERNEL.events)
    return [event for event in _KERNEL.events if event.category == category]
end

clear_events!() = (empty!(_KERNEL.events); _KERNEL.events)
