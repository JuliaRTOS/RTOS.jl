send_message_from_isr(name::AbstractString, message; overwrite::Bool=false) =
    send_message(name, message; overwrite=overwrite)

give_semaphore_from_isr(name::AbstractString) = give_semaphore(name)
notify_task_from_isr(name::AbstractString, count::Integer=1) = notify_task(name, count)

function defer_from_isr!(callback::Function, args...; kwargs...)
    queue = get!(_KERNEL.runtime_stats, "__deferred_isr__", Any[])
    push!(queue, (callback=callback, args=args, kwargs=kwargs))
    return length(queue)
end

function process_deferred_interrupts!()
    queue = get!(_KERNEL.runtime_stats, "__deferred_isr__", Any[])
    processed = 0
    while !isempty(queue)
        item = popfirst!(queue)
        item.callback(item.args...; item.kwargs...)
        processed += 1
    end
    return processed
end
