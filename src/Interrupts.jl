mutable struct InterruptHandler
    name::String
    priority::Int
    callback::Function
    enabled::Bool
    count::Int
end

function register_interrupt(name::AbstractString, callback::Function; priority::Integer=0, enabled::Bool=true)
    name_s = _validate_name(name, :interrupt)
    haskey(_KERNEL.interrupts, name_s) &&
        throw(DuplicateResourceError(:interrupt, name_s))
    handler = InterruptHandler(name_s, _validate_priority(priority), callback, enabled, 0)
    _KERNEL.interrupts[handler.name] = handler
    return handler
end

function trigger_interrupt(name::AbstractString, args...; kwargs...)
    handler = _require_interrupt(name)
    handler.enabled || return nothing
    handler.count += 1
    return handler.callback(args...; kwargs...)
end

function enable_interrupt(name::AbstractString)
    handler = _require_interrupt(name)
    handler.enabled = true
    return handler
end

function disable_interrupt(name::AbstractString)
    handler = _require_interrupt(name)
    handler.enabled = false
    return handler
end

function _require_interrupt(name::AbstractString)
    handler = get(_KERNEL.interrupts, String(name), nothing)
    handler === nothing && throw(ResourceNotFoundError(:interrupt, String(name)))
    return handler
end
