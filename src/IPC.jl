mutable struct MessageQueue
    name::String
    capacity::Int
    buffer::Vector{Any}
    dropped::Int
    send_waiters::Vector{String}
    receive_waiters::Vector{String}
end

MessageQueue(name::AbstractString, capacity::Integer, buffer::Vector{Any},
             dropped::Integer) =
    MessageQueue(String(name), Int(capacity), buffer, Int(dropped),
                 String[], String[])

function create_queue(name::AbstractString, capacity::Integer)
    name_s = _validate_name(name, :queue)
    haskey(_KERNEL.queues, name_s) && throw(DuplicateResourceError(:queue, name_s))
    capacity_i = _positive_int(capacity, "queue capacity")
    queue = MessageQueue(name_s, capacity_i, Any[], 0)
    _KERNEL.queues[queue.name] = queue
    record_event!(:queue, "create"; metadata=Dict(:queue => queue.name,
                                                  :capacity => queue.capacity))
    return queue
end

function send_message(name::AbstractString, message; overwrite::Bool=false,
                      task_name=nothing, block::Bool=false, timeout_ms=nothing)
    queue = _require_queue(name)
    if length(queue.buffer) >= queue.capacity
        if overwrite
            popfirst!(queue.buffer)
            queue.dropped += 1
        elseif block && task_name !== nothing
            _block_task_for_queue!(String(task_name), queue, :send, timeout_ms)
            return false
        else
            return false
        end
    end
    push!(queue.buffer, message)
    _wake_queue_waiter!(queue.receive_waiters)
    record_event!(:queue, "send"; metadata=Dict(:queue => queue.name,
                                                :length => length(queue.buffer)))
    return true
end

function receive_message(name::AbstractString; default=nothing, task_name=nothing,
                         block::Bool=false, timeout_ms=nothing)
    queue = _require_queue(name)
    if isempty(queue.buffer)
        if block && task_name !== nothing
            _block_task_for_queue!(String(task_name), queue, :receive, timeout_ms)
        end
        return default
    end
    message = popfirst!(queue.buffer)
    _wake_queue_waiter!(queue.send_waiters)
    record_event!(:queue, "receive"; metadata=Dict(:queue => queue.name,
                                                   :length => length(queue.buffer)))
    return message
end

queue_length(name::AbstractString) = length(_require_queue(name).buffer)
queue_spaces_available(name::AbstractString) =
    _require_queue(name).capacity - length(_require_queue(name).buffer)

function peek_message(name::AbstractString; default=nothing)
    queue = _require_queue(name)
    isempty(queue.buffer) && return default
    return first(queue.buffer)
end

function reset_queue!(name::AbstractString)
    queue = _require_queue(name)
    empty!(queue.buffer)
    queue.dropped = 0
    while !isempty(queue.send_waiters)
        _wake_queue_waiter!(queue.send_waiters)
    end
    record_event!(:queue, "reset"; metadata=Dict(:queue => queue.name))
    return queue
end

function _require_queue(name::AbstractString)
    queue = get(_KERNEL.queues, String(name), nothing)
    queue === nothing && throw(ResourceNotFoundError(:queue, String(name)))
    return queue
end

function _block_task_for_queue!(task_name::String, queue::MessageQueue,
                                mode::Symbol, timeout_ms)
    task = _require_task(task_name)
    _mark_task_blocked!(task, string("queue:", queue.name, ":", mode), timeout_ms)
    waiters = mode == :send ? queue.send_waiters : queue.receive_waiters
    task_name in waiters || push!(waiters, task_name)
    record_event!(:queue, "block"; metadata=Dict(:queue => queue.name,
                                                 :task => task_name,
                                                 :mode => mode))
    return task
end

function _wake_queue_waiter!(waiters::Vector{String})
    while !isempty(waiters)
        task_name = popfirst!(waiters)
        task = get_task(task_name)
        if task === nothing || task.state != TASK_BLOCKED
            continue
        end
        return _wake_task!(task)
    end
    return nothing
end
