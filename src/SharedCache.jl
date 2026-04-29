mutable struct SharedCache
    name::String
    capacity::Int
    store::Dict{Any,Any}
    order::Vector{Any}
    hits::Int
    misses::Int
end

function create_shared_cache(name::AbstractString; capacity::Integer=128)
    name_s = _validate_name(name, :shared_cache)
    haskey(_KERNEL.shared_caches, name_s) &&
        throw(DuplicateResourceError(:shared_cache, name_s))
    capacity > 0 || throw(CapacityError("cache capacity must be positive"))
    cache = SharedCache(name_s, Int(capacity), Dict{Any,Any}(), Any[], 0, 0)
    _KERNEL.shared_caches[name_s] = cache
    return cache
end

function cache_put!(name::AbstractString, key, value)
    cache = _require_cache(name)
    if !haskey(cache.store, key) && length(cache.store) >= cache.capacity
        first_key = popfirst!(cache.order)
        delete!(cache.store, first_key)
    end
    key in cache.order || push!(cache.order, key)
    cache.store[key] = value
    return value
end

function cache_get(name::AbstractString, key, default=nothing)
    cache = _require_cache(name)
    if haskey(cache.store, key)
        cache.hits += 1
        return cache.store[key]
    end
    cache.misses += 1
    return default
end

function cache_delete!(name::AbstractString, key)
    cache = _require_cache(name)
    existed = haskey(cache.store, key)
    delete!(cache.store, key)
    filter!(item -> item != key, cache.order)
    return existed
end

function cache_stats(name::AbstractString)
    cache = _require_cache(name)
    return (capacity=cache.capacity, size=length(cache.store),
            hits=cache.hits, misses=cache.misses)
end

function _require_cache(name::AbstractString)
    cache = get(_KERNEL.shared_caches, String(name), nothing)
    cache === nothing && throw(ResourceNotFoundError(:shared_cache, String(name)))
    return cache
end
