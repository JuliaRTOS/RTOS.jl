function chrome_trace()
    parts = String["{\"traceEvents\":["]
    first_event = true
    for event in _KERNEL.trace
        first_event || push!(parts, ",")
        first_event = false
        name = _json_escape(event.name)
        cat = _json_escape(String(event.category))
        task = event.task === nothing ? "" : _json_escape(event.task)
        push!(parts, "{\"name\":\"$name\",\"cat\":\"$cat\",\"ph\":\"i\",\"ts\":$(event.time_ms * 1000),\"pid\":1,\"tid\":\"$task\"}")
    end
    push!(parts, "]}")
    return join(parts, "")
end

function _json_escape(text::AbstractString)
    escaped = replace(String(text), "\\" => "\\\\")
    escaped = replace(escaped, "\"" => "\\\"")
    return escaped
end
