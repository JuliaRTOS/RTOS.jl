mutable struct PowerProfile
    name::String
    tick_ms::Int
    max_active_tasks::Int
    metadata::Dict{Symbol,Any}
end

function create_power_profile(name::AbstractString; tick_ms::Integer=1,
                              max_active_tasks::Integer=typemax(Int),
                              metadata=Dict{Symbol,Any}())
    name_s = _validate_name(name, :power_profile)
    haskey(_KERNEL.power_profiles, name_s) &&
        throw(DuplicateResourceError(:power_profile, name_s))
    tick_ms > 0 || throw(InvalidStateError("power profile tick_ms must be positive"))
    max_active_tasks > 0 || throw(CapacityError("max_active_tasks must be positive"))
    profile = PowerProfile(name_s, Int(tick_ms), Int(max_active_tasks),
                           _metadata_dict(metadata))
    _KERNEL.power_profiles[name_s] = profile
    return profile
end

function set_power_profile!(name::AbstractString)
    profile = _require_power_profile(name)
    set_config!(:power_profile, profile.name)
    set_config!(:tick_ms, profile.tick_ms)
    set_config!(:max_active_tasks, profile.max_active_tasks)
    return profile
end

function current_power_profile()
    name = get_config(:power_profile, nothing)
    name === nothing && return nothing
    return get(_KERNEL.power_profiles, String(name), nothing)
end

function _require_power_profile(name::AbstractString)
    profile = get(_KERNEL.power_profiles, String(name), nothing)
    profile === nothing && throw(ResourceNotFoundError(:power_profile, String(name)))
    return profile
end
