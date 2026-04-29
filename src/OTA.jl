mutable struct OTAUpdater
    name::String
    stage::Function
    verify::Function
    apply::Function
    staged::Any
end

function register_ota_updater!(name::AbstractString; stage, verify, apply)
    name_s = _validate_name(name, :ota_updater)
    haskey(_KERNEL.ota_updaters, name_s) &&
        throw(DuplicateResourceError(:ota_updater, name_s))
    updater = OTAUpdater(name_s, stage, verify, apply, nothing)
    _KERNEL.ota_updaters[name_s] = updater
    return updater
end

function stage_update!(name::AbstractString, artifact)
    updater = _require_ota_updater(name)
    updater.staged = updater.stage(artifact)
    record_event!(:ota, "stage"; metadata=Dict(:updater => updater.name))
    return updater.staged
end

function verify_update!(name::AbstractString)
    updater = _require_ota_updater(name)
    updater.staged === nothing && throw(InvalidStateError("no staged update for $(name)"))
    result = updater.verify(updater.staged)
    record_event!(:ota, "verify"; metadata=Dict(:updater => updater.name, :result => result))
    return result
end

function apply_update!(name::AbstractString)
    updater = _require_ota_updater(name)
    verify_update!(name) || throw(InvalidStateError("OTA verification failed for $(name)"))
    result = updater.apply(updater.staged)
    record_event!(:ota, "apply"; metadata=Dict(:updater => updater.name))
    return result
end

function _require_ota_updater(name::AbstractString)
    updater = get(_KERNEL.ota_updaters, String(name), nothing)
    updater === nothing && throw(ResourceNotFoundError(:ota_updater, String(name)))
    return updater
end
