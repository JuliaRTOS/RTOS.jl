function set_task_local!(task_name::AbstractString, key::Symbol, value)
    task = _require_task(task_name)
    storage = get!(_KERNEL.task_local, task.name, Dict{Symbol,Any}())
    storage[key] = value
    return value
end

function get_task_local(task_name::AbstractString, key::Symbol, default=nothing)
    storage = get(_KERNEL.task_local, String(task_name), Dict{Symbol,Any}())
    return get(storage, key, default)
end

function delete_task_local!(task_name::AbstractString, key::Symbol)
    storage = get(_KERNEL.task_local, String(task_name), nothing)
    storage === nothing && return false
    existed = haskey(storage, key)
    delete!(storage, key)
    return existed
end
