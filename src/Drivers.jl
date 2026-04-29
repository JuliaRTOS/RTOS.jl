mutable struct DeviceDriver
    name::String
    read::Union{Nothing,Function}
    write::Union{Nothing,Function}
    control::Union{Nothing,Function}
    metadata::Dict{Symbol,Any}
end

function register_driver(name::AbstractString; read=nothing, write=nothing, control=nothing,
                         metadata=Dict{Symbol,Any}())
    name_s = _validate_name(name, :driver)
    haskey(_KERNEL.drivers, name_s) && throw(DuplicateResourceError(:driver, name_s))
    driver = DeviceDriver(name_s, read, write, control, _metadata_dict(metadata))
    _KERNEL.drivers[driver.name] = driver
    return driver
end

get_driver(name::AbstractString) = get(_KERNEL.drivers, String(name), nothing)

function read_device(name::AbstractString, args...; kwargs...)
    driver = _require_driver(name)
    driver.read === nothing &&
        throw(InvalidStateError("driver $name does not implement read"))
    return driver.read(args...; kwargs...)
end

function write_device(name::AbstractString, args...; kwargs...)
    driver = _require_driver(name)
    driver.write === nothing &&
        throw(InvalidStateError("driver $name does not implement write"))
    return driver.write(args...; kwargs...)
end

function control_device(name::AbstractString, args...; kwargs...)
    driver = _require_driver(name)
    driver.control === nothing &&
        throw(InvalidStateError("driver $name does not implement control"))
    return driver.control(args...; kwargs...)
end

function _require_driver(name::AbstractString)
    driver = get_driver(name)
    driver === nothing && throw(ResourceNotFoundError(:driver, String(name)))
    return driver
end
