function init_queue!(queue::MessageQueue, name::AbstractString, capacity::Integer)
    name_s = _validate_name(name, :queue)
    queue.name = name_s
    queue.capacity = Int(capacity)
    empty!(queue.buffer)
    queue.dropped = 0
    empty!(queue.send_waiters)
    empty!(queue.receive_waiters)
    _KERNEL.queues[name_s] = queue
    return queue
end

function init_mutex!(mutex::RTOSMutex, name::AbstractString; recursive::Bool=false)
    name_s = _validate_name(name, :mutex)
    mutex.name = name_s
    mutex.owner = nothing
    mutex.lock_count = 0
    mutex.recursive = recursive
    empty!(mutex.waiters)
    empty!(mutex.graph.waits_for)
    _KERNEL.mutexes[name_s] = mutex
    return mutex
end

function init_timer!(timer::RTOSTimer, name::AbstractString, period_ms::Integer,
                     callback::Function; oneshot::Bool=false)
    name_s = _validate_name(name, :timer)
    timer.name = name_s
    timer.period_ms = Int(period_ms)
    timer.callback = callback
    timer.oneshot = oneshot
    timer.active = false
    timer.next_fire_ms = 0
    timer.fire_count = 0
    _KERNEL.timers[name_s] = timer
    return timer
end

function init_event_group!(group::EventGroup, name::AbstractString; initial_bits::Integer=0)
    name_s = _validate_name(name, :event_group)
    group.name = name_s
    group.bits = UInt64(initial_bits)
    empty!(group.waiters)
    _KERNEL.event_groups[name_s] = group
    return group
end

function init_stream_buffer!(stream::StreamBuffer, name::AbstractString,
                             capacity::Integer; trigger_level::Integer=1)
    name_s = _validate_name(name, :stream_buffer)
    stream.name = name_s
    stream.buffer = RingBuffer{UInt8}(capacity)
    stream.trigger_level = Int(trigger_level)
    _KERNEL.stream_buffers[name_s] = stream
    return stream
end
