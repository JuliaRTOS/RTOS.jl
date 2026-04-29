abstract type AbstractHeapScheme end

mutable struct Heap1 <: AbstractHeapScheme
    name::String
    capacity::Int
    used::Int
end

mutable struct Heap2 <: AbstractHeapScheme
    name::String
    capacity::Int
    used::Int
    allocations::IdDict{Vector{UInt8},Int}
end

mutable struct Heap4 <: AbstractHeapScheme
    name::String
    capacity::Int
    used::Int
    allocations::IdDict{Vector{UInt8},Int}
    frees::Int
end

mutable struct RegionHeap <: AbstractHeapScheme
    name::String
    regions::Vector{Tuple{String,Int}}
    used::Dict{String,Int}
    allocations::IdDict{Vector{UInt8},Tuple{String,Int}}
end

function create_heap!(name::AbstractString, kind::Symbol, capacity::Integer; regions=Tuple{String,Int}[])
    name_s = _validate_name(name, :heap)
    haskey(_KERNEL.heaps, name_s) && throw(DuplicateResourceError(:heap, name_s))
    capacity >= 0 || throw(CapacityError("heap capacity must be non-negative"))
    heap = if kind == :heap1
        Heap1(name_s, Int(capacity), 0)
    elseif kind == :heap2
        Heap2(name_s, Int(capacity), 0, IdDict{Vector{UInt8},Int}())
    elseif kind == :heap4
        Heap4(name_s, Int(capacity), 0, IdDict{Vector{UInt8},Int}(), 0)
    elseif kind == :region
        RegionHeap(name_s, Tuple{String,Int}[regions...],
                   Dict{String,Int}(), IdDict{Vector{UInt8},Tuple{String,Int}}())
    else
        throw(InvalidStateError("unknown heap kind: $(kind)"))
    end
    _KERNEL.heaps[name_s] = heap
    return heap
end

function heap_alloc!(name::AbstractString, bytes::Integer)
    bytes >= 0 || throw(CapacityError("allocation size must be non-negative"))
    return _heap_alloc!(_require_heap(name), Int(bytes))
end

heap_free!(name::AbstractString, block::Vector{UInt8}) =
    _heap_free!(_require_heap(name), block)

heap_stats(name::AbstractString) = _heap_stats(_require_heap(name))

function _heap_alloc!(heap::Heap1, bytes::Int)
    heap.used + bytes > heap.capacity && return nothing
    heap.used += bytes
    return zeros(UInt8, bytes)
end

function _heap_alloc!(heap::Union{Heap2,Heap4}, bytes::Int)
    heap.used + bytes > heap.capacity && return nothing
    block = zeros(UInt8, bytes)
    heap.allocations[block] = bytes
    heap.used += bytes
    return block
end

function _heap_alloc!(heap::RegionHeap, bytes::Int)
    for (region, capacity) in heap.regions
        used = get(heap.used, region, 0)
        if used + bytes <= capacity
            block = zeros(UInt8, bytes)
            heap.used[region] = used + bytes
            heap.allocations[block] = (region, bytes)
            return block
        end
    end
    return nothing
end

_heap_free!(heap::Heap1, block::Vector{UInt8}) =
    throw(InvalidStateError("heap1 does not support free"))

function _heap_free!(heap::Union{Heap2,Heap4}, block::Vector{UInt8})
    haskey(heap.allocations, block) || throw(ResourceNotFoundError(:heap_allocation, "block"))
    bytes = heap.allocations[block]
    delete!(heap.allocations, block)
    heap.used -= bytes
    heap isa Heap4 && (heap.frees += 1)
    return heap.used
end

function _heap_free!(heap::RegionHeap, block::Vector{UInt8})
    haskey(heap.allocations, block) || throw(ResourceNotFoundError(:heap_allocation, "block"))
    region, bytes = heap.allocations[block]
    delete!(heap.allocations, block)
    heap.used[region] = get(heap.used, region, 0) - bytes
    return heap.used[region]
end

_heap_stats(heap::Heap1) = (kind=:heap1, capacity=heap.capacity, used=heap.used, free=heap.capacity - heap.used)
_heap_stats(heap::Heap2) = (kind=:heap2, capacity=heap.capacity, used=heap.used, free=heap.capacity - heap.used, allocations=length(heap.allocations))
_heap_stats(heap::Heap4) = (kind=:heap4, capacity=heap.capacity, used=heap.used, free=heap.capacity - heap.used, allocations=length(heap.allocations), frees=heap.frees)
_heap_stats(heap::RegionHeap) = (kind=:region, regions=heap.regions, used=copy(heap.used), allocations=length(heap.allocations))

function _require_heap(name::AbstractString)
    heap = get(_KERNEL.heaps, String(name), nothing)
    heap === nothing && throw(ResourceNotFoundError(:heap, String(name)))
    return heap
end
