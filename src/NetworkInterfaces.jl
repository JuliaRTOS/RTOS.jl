mutable struct NetworkInterface
    name::String
    send::Union{Nothing,Function}
    receive::Union{Nothing,Function}
    status::Union{Nothing,Function}
    metadata::Dict{Symbol,Any}
end

function register_network_interface!(name::AbstractString; send=nothing, receive=nothing,
                                     status=nothing, metadata=Dict{Symbol,Any}())
    name_s = _validate_name(name, :network_interface)
    haskey(_KERNEL.network_interfaces, name_s) &&
        throw(DuplicateResourceError(:network_interface, name_s))
    iface = NetworkInterface(name_s, send, receive, status, _metadata_dict(metadata))
    _KERNEL.network_interfaces[name_s] = iface
    return iface
end

function network_send!(name::AbstractString, payload)
    iface = _require_network_interface(name)
    iface.send === nothing && throw(InvalidStateError("network interface $(name) does not implement send"))
    return iface.send(payload)
end

function network_receive!(name::AbstractString)
    iface = _require_network_interface(name)
    iface.receive === nothing && throw(InvalidStateError("network interface $(name) does not implement receive"))
    return iface.receive()
end

function network_status(name::AbstractString)
    iface = _require_network_interface(name)
    iface.status === nothing && return :unknown
    return iface.status()
end

function _require_network_interface(name::AbstractString)
    iface = get(_KERNEL.network_interfaces, String(name), nothing)
    iface === nothing && throw(ResourceNotFoundError(:network_interface, String(name)))
    return iface
end
