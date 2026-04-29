const TASK_READY = :ready
const TASK_RUNNING = :running
const TASK_SUSPENDED = :suspended
const TASK_STOPPED = :stopped
const TASK_COMPLETED = :completed
const TASK_BLOCKED = :blocked
const TASK_FAILED = :failed

abstract type RTOSException <: Exception end

struct DuplicateResourceError <: RTOSException
    kind::Symbol
    name::String
end

struct InvalidStateError <: RTOSException
    message::String
end

struct ResourceNotFoundError <: RTOSException
    kind::Symbol
    name::String
end

struct CapacityError <: RTOSException
    message::String
end

struct TimeoutError <: RTOSException
    message::String
end

struct IntegrationUnavailableError <: RTOSException
    package::String
    feature::String
end

Base.showerror(io::IO, err::DuplicateResourceError) =
    print(io, err.kind, " already exists: ", err.name)

Base.showerror(io::IO, err::InvalidStateError) = print(io, err.message)
Base.showerror(io::IO, err::ResourceNotFoundError) =
    print(io, "unknown ", err.kind, ": ", err.name)
Base.showerror(io::IO, err::CapacityError) = print(io, err.message)
Base.showerror(io::IO, err::TimeoutError) = print(io, err.message)
Base.showerror(io::IO, err::IntegrationUnavailableError) =
    print(io, err.feature, " requires package ", err.package)

mutable struct RTTask
    name::String
    action::Function
    priority::Int
    effective_priority::Int
    state::Symbol
    deadline_ms::Union{Nothing,Int}
    period_ms::Union{Nothing,Int}
    repeat::Bool
    notifications::Int
    waiting_on::Union{Nothing,String}
    blocked_until_ms::Union{Nothing,Int}
    run_count::Int
    last_result::Any
    last_error::Any
    created_at::Int
    last_run_at::Union{Nothing,Int}
    next_release_ms::Int
    stack_size::Int
    stack_high_water_mark::Int
    core_affinity::Vector{Int}
    assigned_core::Union{Nothing,Int}
    metadata::Dict{Symbol,Any}
end

function RTTask(name::AbstractString, action::Function, priority::Integer;
                deadline_ms=nothing, period_ms=nothing, repeat::Bool=false,
                stack_size::Integer=1024, core_affinity=Int[],
                metadata=Dict{Symbol,Any}())
    stack_size_i = _positive_int(stack_size, "stack_size")
    RTTask(String(name), action, Int(priority), Int(priority), TASK_READY,
           _optional_int(deadline_ms, "deadline_ms"; min_value=0),
           _optional_int(period_ms, "period_ms"; min_value=1),
           repeat, 0, nothing, nothing, 0, nothing, nothing, 0, nothing, 0,
           stack_size_i, stack_size_i, Int[Int(core) for core in core_affinity],
           nothing,
           _metadata_dict(metadata))
end

mutable struct KernelState
    tasks::Dict{String,RTTask}
    queues::Dict{String,Any}
    mutexes::Dict{String,Any}
    semaphores::Dict{String,Any}
    timers::Dict{String,Any}
    interrupts::Dict{String,Any}
    drivers::Dict{String,Any}
    memory_pools::Dict{String,Any}
    allocators::Dict{String,Any}
    watchdogs::Dict{String,Any}
    task_pools::Dict{String,Any}
    shared_caches::Dict{String,Any}
    periodic_jobs::Dict{String,Any}
    config::Dict{Symbol,Any}
    events::Vector{Any}
    analytics::Dict{Symbol,Any}
    monitors::Dict{String,Any}
    power_profiles::Dict{String,Any}
    fault_policies::Dict{String,Any}
    ml_models::Dict{String,Any}
    event_groups::Dict{String,Any}
    stream_buffers::Dict{String,Any}
    message_buffers::Dict{String,Any}
    queue_sets::Dict{String,Any}
    hooks::Dict{Symbol,Vector{Function}}
    ports::Dict{String,Any}
    runtime_stats::Dict{String,Any}
    trace::Vector{Any}
    rtos_config::Any
    contracts::Dict{String,Any}
    capabilities::Dict{String,Any}
    memory_regions::Dict{String,Any}
    build_targets::Dict{String,Any}
    boards::Dict{String,Any}
    daemon::Any
    heaps::Dict{String,Any}
    task_local::Dict{String,Any}
    safety_profiles::Dict{String,Any}
    network_interfaces::Dict{String,Any}
    ota_updaters::Dict{String,Any}
    logs::Vector{Any}
    log_level::Int
    running::Bool
    clock_ms::Int
    sequence::Int
    current_task::Union{Nothing,String}
end

function KernelState()
    KernelState(Dict{String,RTTask}(), Dict{String,Any}(), Dict{String,Any}(),
                Dict{String,Any}(), Dict{String,Any}(), Dict{String,Any}(),
                Dict{String,Any}(), Dict{String,Any}(), Dict{String,Any}(),
                Dict{String,Any}(), Dict{String,Any}(), Dict{String,Any}(),
                Dict{String,Any}(), Dict{Symbol,Any}(), Any[],
                Dict{Symbol,Any}(), Dict{String,Any}(), Dict{String,Any}(),
                Dict{String,Any}(), Dict{String,Any}(), Dict{String,Any}(),
                Dict{String,Any}(), Dict{String,Any}(), Dict{String,Any}(),
                Dict{Symbol,Vector{Function}}(), Dict{String,Any}(),
                Dict{String,Any}(), Any[], nothing, Dict{String,Any}(),
                Dict{String,Any}(), Dict{String,Any}(), Dict{String,Any}(),
                Dict{String,Any}(), nothing, Dict{String,Any}(),
                Dict{String,Any}(), Dict{String,Any}(), Dict{String,Any}(),
                Dict{String,Any}(), Any[], 2, false, 0, 0, nothing)
end

const _KERNEL = KernelState()
kernel_state() = _KERNEL

function reset_kernel!()
    empty!(_KERNEL.tasks); empty!(_KERNEL.queues); empty!(_KERNEL.mutexes)
    empty!(_KERNEL.semaphores); empty!(_KERNEL.timers); empty!(_KERNEL.interrupts)
    empty!(_KERNEL.drivers); empty!(_KERNEL.memory_pools); empty!(_KERNEL.allocators)
    empty!(_KERNEL.watchdogs); empty!(_KERNEL.logs)
    empty!(_KERNEL.task_pools); empty!(_KERNEL.shared_caches)
    empty!(_KERNEL.periodic_jobs); empty!(_KERNEL.config); empty!(_KERNEL.events)
    empty!(_KERNEL.analytics); empty!(_KERNEL.monitors)
    empty!(_KERNEL.power_profiles); empty!(_KERNEL.fault_policies)
    empty!(_KERNEL.ml_models)
    empty!(_KERNEL.event_groups); empty!(_KERNEL.stream_buffers)
    empty!(_KERNEL.message_buffers); empty!(_KERNEL.queue_sets)
    empty!(_KERNEL.hooks); empty!(_KERNEL.ports); empty!(_KERNEL.runtime_stats)
    empty!(_KERNEL.trace)
    _KERNEL.rtos_config = nothing
    empty!(_KERNEL.contracts); empty!(_KERNEL.capabilities)
    empty!(_KERNEL.memory_regions); empty!(_KERNEL.build_targets)
    empty!(_KERNEL.boards)
    _KERNEL.daemon = nothing
    empty!(_KERNEL.heaps); empty!(_KERNEL.task_local)
    empty!(_KERNEL.safety_profiles); empty!(_KERNEL.network_interfaces)
    empty!(_KERNEL.ota_updaters)
    if isdefined(@__MODULE__, :_GLOBAL_DEADLOCK_GRAPH)
        empty!(_GLOBAL_DEADLOCK_GRAPH.waits_for)
    end
    _KERNEL.log_level = 2
    _KERNEL.running = false
    _KERNEL.clock_ms = 0
    _KERNEL.sequence = 0
    _KERNEL.current_task = nothing
    return _KERNEL
end

function create_task(name::AbstractString, action::Function, priority::Integer;
                     deadline_ms=nothing, period_ms=nothing, repeat::Bool=false,
                     autostart::Bool=true, stack_size::Integer=1024,
                     core_affinity=Int[], metadata=Dict{Symbol,Any}())
    name_s = _validate_name(name, :task)
    haskey(_KERNEL.tasks, name_s) && throw(DuplicateResourceError(:task, name_s))
    config = current_config()
    length(_KERNEL.tasks) < config.max_tasks ||
        throw(CapacityError("max_tasks exceeded"))
    priority_i = _validate_priority(priority)
    priority_i < config.max_priorities ||
        throw(InvalidStateError("priority exceeds configured max_priorities"))
    _optional_int(deadline_ms, "deadline_ms"; min_value=0)
    _optional_int(period_ms, "period_ms"; min_value=1)
    _KERNEL.sequence += 1
    task = RTTask(name_s, action, priority_i; deadline_ms=deadline_ms,
                  period_ms=period_ms, repeat=repeat, stack_size=stack_size,
                  core_affinity=core_affinity, metadata=metadata)
    task.created_at = _KERNEL.sequence
    task.next_release_ms = _KERNEL.clock_ms
    task.state = autostart ? TASK_READY : TASK_SUSPENDED
    _KERNEL.tasks[task.name] = task
    return task
end

get_task(name::AbstractString) = get(_KERNEL.tasks, String(name), nothing)
list_tasks() = collect(values(_KERNEL.tasks))
task_state(name::AbstractString) = get_task(name) === nothing ? nothing : get_task(name).state

function suspend_task(name::AbstractString)
    task = _require_task(name)
    task.state = TASK_SUSPENDED
    return task
end

function resume_task(name::AbstractString)
    task = _require_task(name)
    task.state in (TASK_STOPPED, TASK_COMPLETED) &&
        throw(InvalidStateError("cannot resume $(task.state) task: $name"))
    task.state = TASK_READY
    task.waiting_on = nothing
    return task
end

function stop_task(name::AbstractString)
    task = _require_task(name)
    task.state = TASK_STOPPED
    return task
end

function delete_task(name::AbstractString)
    task = _require_task(name)
    delete!(_KERNEL.tasks, String(name))
    return task
end

function set_task_priority!(name::AbstractString, priority::Integer)
    task = _require_task(name)
    priority_i = _validate_priority(priority)
    task.priority = priority_i
    task.effective_priority = priority_i
    if isdefined(@__MODULE__, :_refresh_all_mutex_priorities!)
        _refresh_all_mutex_priorities!()
    end
    return task
end

function set_task_deadline!(name::AbstractString, deadline_ms)
    task = _require_task(name)
    task.deadline_ms = _optional_int(deadline_ms, "deadline_ms"; min_value=0)
    return task
end

function notify_task(name::AbstractString, count::Integer=1)
    Int(count) < 0 && throw(InvalidStateError("notification count must be non-negative"))
    task = _require_task(name)
    task.notifications += Int(count)
    if task.state == TASK_BLOCKED && task.waiting_on == "notification"
        _wake_task!(task)
    end
    return task.notifications
end

function notify_task_value(name::AbstractString, value::Integer=1; action::Symbol=:increment)
    task = _require_task(name)
    value_i = Int(value)
    if action == :increment
        task.notifications += value_i
    elseif action == :set_bits
        task.notifications |= value_i
    elseif action == :overwrite
        task.notifications = value_i
    elseif action == :no_overwrite
        task.notifications == 0 || return false
        task.notifications = value_i
    else
        throw(InvalidStateError("unsupported notification action: $(action)"))
    end
    if task.state == TASK_BLOCKED && task.waiting_on == "notification"
        _wake_task!(task)
    end
    return task.notifications
end

function take_notification(name::AbstractString; clear::Bool=true, block::Bool=false,
                           timeout_ms=nothing)
    task = _require_task(name)
    value = task.notifications
    if value == 0 && block
        _mark_task_blocked!(task, "notification", timeout_ms)
    elseif clear
        task.notifications = 0
    else
        task.notifications = max(0, task.notifications - 1)
    end
    return value
end

function delay_task(name::AbstractString, delay_ms::Integer)
    delay_i = _to_int(delay_ms, "delay_ms")
    delay_i >= 0 || throw(InvalidStateError("delay_ms must be non-negative"))
    task = _require_task(name)
    _mark_task_blocked!(task, "delay", delay_i)
    return task
end

function stack_stats(name::AbstractString)
    task = _require_task(name)
    return (stack_size=task.stack_size, high_water_mark=task.stack_high_water_mark)
end

yield_task() = :yield

function _require_task(name::AbstractString)
    task = get_task(name)
    task === nothing && throw(ResourceNotFoundError(:task, String(name)))
    return task
end
