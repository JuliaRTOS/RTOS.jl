struct Capability
    name::String
end

mutable struct MemoryRegion
    name::String
    base::Int
    size::Int
    permissions::Set{Symbol}
    owners::Vector{String}
end

function grant_capability!(task_name::AbstractString, capability::AbstractString)
    task = _require_task(task_name)
    caps = get!(_KERNEL.capabilities, task.name, Set{String}())
    push!(caps, String(capability))
    return Capability(String(capability))
end

function revoke_capability!(task_name::AbstractString, capability::AbstractString)
    caps = get(_KERNEL.capabilities, String(task_name), Set{String}())
    delete!(caps, String(capability))
    return caps
end

function has_capability(task_name::AbstractString, capability::AbstractString)
    caps = get(_KERNEL.capabilities, String(task_name), Set{String}())
    return String(capability) in caps
end

function define_memory_region!(name::AbstractString, base::Integer, size::Integer;
                               permissions=Set([:read, :write]))
    name_s = _validate_name(name, :memory_region)
    haskey(_KERNEL.memory_regions, name_s) &&
        throw(DuplicateResourceError(:memory_region, name_s))
    size > 0 || throw(CapacityError("memory region size must be positive"))
    region = MemoryRegion(name_s, Int(base), Int(size), Set{Symbol}(permissions), String[])
    _KERNEL.memory_regions[name_s] = region
    return region
end

function assign_region!(task_name::AbstractString, region_name::AbstractString)
    task = _require_task(task_name)
    region = get(_KERNEL.memory_regions, String(region_name), nothing)
    region === nothing && throw(ResourceNotFoundError(:memory_region, String(region_name)))
    task.name in region.owners || push!(region.owners, task.name)
    return region
end

function validate_security()
    problems = String[]
    config = current_config()
    if config.deterministic_only
        for event in events(:ml)
            push!(problems, "ML event in deterministic mode: $(event.name)")
        end
    end
    for task in values(_KERNEL.tasks)
        if get(task.metadata, :privileged, false) && !has_capability(task.name, "privileged")
            push!(problems, "$(task.name) marked privileged without privileged capability")
        end
    end
    return problems
end
