mutable struct StreamBuffer
    name::String
    buffer::RingBuffer{UInt8}
    trigger_level::Int
end

mutable struct MessageBuffer
    name::String
    capacity::Int
    messages::RingBuffer{Vector{UInt8}}
end

function create_stream_buffer(name::AbstractString, capacity::Integer; trigger_level::Integer=1)
    name_s = _validate_name(name, :stream_buffer)
    haskey(_KERNEL.stream_buffers, name_s) &&
        throw(DuplicateResourceError(:stream_buffer, name_s))
    capacity > 0 || throw(CapacityError("stream buffer capacity must be positive"))
    trigger_level > 0 || throw(CapacityError("trigger_level must be positive"))
    stream = StreamBuffer(name_s, RingBuffer{UInt8}(capacity), Int(trigger_level))
    _KERNEL.stream_buffers[name_s] = stream
    return stream
end

function stream_send!(name::AbstractString, bytes)
    stream = _require_stream_buffer(name)
    sent = 0
    for byte in bytes
        push_ring!(stream.buffer, UInt8(byte)) || break
        sent += 1
    end
    return sent
end

function stream_receive!(name::AbstractString, max_bytes::Integer)
    stream = _require_stream_buffer(name)
    out = UInt8[]
    for _ in 1:Int(max_bytes)
        ring_empty(stream.buffer) && break
        push!(out, pop_ring!(stream.buffer))
    end
    return out
end

stream_available(name::AbstractString) = ring_length(_require_stream_buffer(name).buffer)

function create_message_buffer(name::AbstractString, capacity::Integer)
    name_s = _validate_name(name, :message_buffer)
    haskey(_KERNEL.message_buffers, name_s) &&
        throw(DuplicateResourceError(:message_buffer, name_s))
    capacity > 0 || throw(CapacityError("message buffer capacity must be positive"))
    buffer = MessageBuffer(name_s, Int(capacity), RingBuffer{Vector{UInt8}}(capacity))
    _KERNEL.message_buffers[name_s] = buffer
    return buffer
end

function message_send!(name::AbstractString, bytes)
    buffer = _require_message_buffer(name)
    return push_ring!(buffer.messages, UInt8[UInt8(byte) for byte in bytes])
end

function message_receive!(name::AbstractString; default=nothing)
    buffer = _require_message_buffer(name)
    return pop_ring!(buffer.messages; default=default)
end

message_available(name::AbstractString) = ring_length(_require_message_buffer(name).messages)

function _require_stream_buffer(name::AbstractString)
    stream = get(_KERNEL.stream_buffers, String(name), nothing)
    stream === nothing && throw(ResourceNotFoundError(:stream_buffer, String(name)))
    return stream
end

function _require_message_buffer(name::AbstractString)
    buffer = get(_KERNEL.message_buffers, String(name), nothing)
    buffer === nothing && throw(ResourceNotFoundError(:message_buffer, String(name)))
    return buffer
end
