struct LogRecord
    time_ms::Int
    level::Int
    level_name::Symbol
    message::String
    task::Union{Nothing,String}
    metadata::Dict{Symbol,Any}
end

const LOG_DEBUG = 1
const LOG_INFO = 2
const LOG_WARN = 3
const LOG_ERROR = 4

function set_log_level!(level)
    _KERNEL.log_level = _log_level(level)
    return _KERNEL.log_level
end

function _log_level(level)
    level isa Integer && return Int(level)
    table = Dict(:debug => LOG_DEBUG, :info => LOG_INFO, :warn => LOG_WARN,
                 :warning => LOG_WARN, :error => LOG_ERROR)
    return get(table, Symbol(level), LOG_INFO)
end

function _log(level::Symbol, message::AbstractString; metadata=Dict{Symbol,Any}())
    value = _log_level(level)
    if value >= _KERNEL.log_level
        push!(_KERNEL.logs, LogRecord(_KERNEL.clock_ms, value, level, String(message),
                                      _KERNEL.current_task, _metadata_dict(metadata)))
    end
    return nothing
end

log_debug(message::AbstractString; metadata=Dict{Symbol,Any}()) = _log(:debug, message; metadata=metadata)
log_info(message::AbstractString; metadata=Dict{Symbol,Any}()) = _log(:info, message; metadata=metadata)
log_warn(message::AbstractString; metadata=Dict{Symbol,Any}()) = _log(:warn, message; metadata=metadata)
log_error(message::AbstractString; metadata=Dict{Symbol,Any}()) = _log(:error, message; metadata=metadata)

function recent_logs(n::Integer=length(_KERNEL.logs))
    count = min(Int(n), length(_KERNEL.logs))
    count <= 0 && return Any[]
    return _KERNEL.logs[end-count+1:end]
end

clear_logs!() = (empty!(_KERNEL.logs); _KERNEL.logs)
