mutable struct SafetyProfile
    name::String
    require_contracts::Bool
    require_stack_budget::Bool
    require_memory_regions::Bool
    forbid_dynamic_allocation::Bool
    forbid_ml_events::Bool
end

function create_safety_profile(name::AbstractString; require_contracts::Bool=true,
                               require_stack_budget::Bool=true,
                               require_memory_regions::Bool=false,
                               forbid_dynamic_allocation::Bool=true,
                               forbid_ml_events::Bool=true)
    name_s = _validate_name(name, :safety_profile)
    haskey(_KERNEL.safety_profiles, name_s) &&
        throw(DuplicateResourceError(:safety_profile, name_s))
    profile = SafetyProfile(name_s, require_contracts, require_stack_budget,
                            require_memory_regions, forbid_dynamic_allocation,
                            forbid_ml_events)
    _KERNEL.safety_profiles[name_s] = profile
    return profile
end

function validate_safety_profile(name::AbstractString)
    profile = _require_safety_profile(name)
    problems = String[]
    if profile.require_contracts
        for task in values(_KERNEL.tasks)
            get_task_contract(task.name) === nothing &&
                push!(problems, "$(task.name) missing real-time contract")
        end
    end
    if profile.require_memory_regions
        for task in values(_KERNEL.tasks)
            owned = false
            for region in values(_KERNEL.memory_regions)
                task.name in region.owners && (owned = true)
            end
            owned || push!(problems, "$(task.name) missing memory region")
        end
    end
    if profile.forbid_dynamic_allocation && current_config().allow_dynamic_allocation
        push!(problems, "dynamic allocation is enabled")
    end
    if profile.forbid_ml_events && !isempty(events(:ml))
        push!(problems, "ML events observed in safety profile")
    end
    append!(problems, validate_security())
    return problems
end

function safety_report(name::AbstractString)
    problems = validate_safety_profile(name)
    return (profile=String(name), passed=isempty(problems), problems=problems,
            schedulability=schedulability_report(), registry=kernel_snapshot())
end

function _require_safety_profile(name::AbstractString)
    profile = get(_KERNEL.safety_profiles, String(name), nothing)
    profile === nothing && throw(ResourceNotFoundError(:safety_profile, String(name)))
    return profile
end
