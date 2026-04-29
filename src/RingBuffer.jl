mutable struct RingBuffer{T}
    data::Vector{Union{Nothing,T}}
    head::Int
    tail::Int
    len::Int
    overwrite::Bool
end

function RingBuffer{T}(capacity::Integer; overwrite::Bool=false) where T
    capacity > 0 || throw(CapacityError("ring buffer capacity must be positive"))
    RingBuffer{T}(Vector{Union{Nothing,T}}(fill(nothing, Int(capacity))),
                  1, 1, 0, overwrite)
end

RingBuffer(capacity::Integer; overwrite::Bool=false) =
    RingBuffer{Any}(capacity; overwrite=overwrite)

ring_capacity(buffer::RingBuffer) = length(buffer.data)
ring_length(buffer::RingBuffer) = buffer.len
ring_empty(buffer::RingBuffer) = buffer.len == 0
ring_full(buffer::RingBuffer) = buffer.len == ring_capacity(buffer)

function push_ring!(buffer::RingBuffer{T}, item) where T
    if ring_full(buffer)
        if !buffer.overwrite
            return false
        end
        buffer.data[buffer.tail] = item
        buffer.tail = _ring_next(buffer, buffer.tail)
        buffer.head = buffer.tail
        return true
    end
    buffer.data[buffer.tail] = item
    buffer.tail = _ring_next(buffer, buffer.tail)
    buffer.len += 1
    return true
end

function pop_ring!(buffer::RingBuffer; default=nothing)
    ring_empty(buffer) && return default
    item = buffer.data[buffer.head]
    buffer.data[buffer.head] = nothing
    buffer.head = _ring_next(buffer, buffer.head)
    buffer.len -= 1
    return item
end

function peek_ring(buffer::RingBuffer; default=nothing)
    ring_empty(buffer) && return default
    return buffer.data[buffer.head]
end

function clear_ring!(buffer::RingBuffer)
    fill!(buffer.data, nothing)
    buffer.head = 1
    buffer.tail = 1
    buffer.len = 0
    return buffer
end

_ring_next(buffer::RingBuffer, index::Int) =
    index == ring_capacity(buffer) ? 1 : index + 1
