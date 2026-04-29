function runtime_stats()
    stats = Dict{Symbol,Any}()
    stats[:clock_ms] = _KERNEL.clock_ms
    stats[:tasks] = task_run_counts()
    stats[:events] = event_counts()
    stats[:resource] = latest_resources()
    stats[:trace_records] = length(_KERNEL.trace)
    return stats
end

trace_records() = copy(_KERNEL.trace)
clear_trace!() = (empty!(_KERNEL.trace); _KERNEL.trace)

function export_trace()
    lines = String[]
    for item in _KERNEL.trace
        push!(lines, string(item.time_ms, ",", item.category, ",", item.name, ",",
                           item.task === nothing ? "" : item.task))
    end
    return join(lines, "\n")
end
