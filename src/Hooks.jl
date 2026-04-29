function register_hook!(kind::Symbol, hook::Function)
    hooks = get!(_KERNEL.hooks, kind, Function[])
    push!(hooks, hook)
    return hook
end

function clear_hooks!(kind::Union{Nothing,Symbol}=nothing)
    if kind === nothing
        empty!(_KERNEL.hooks)
    else
        delete!(_KERNEL.hooks, kind)
    end
    return _KERNEL.hooks
end

function run_hooks(kind::Symbol, args...; kwargs...)
    for hook in get(_KERNEL.hooks, kind, Function[])
        hook(args...; kwargs...)
    end
    return nothing
end

register_tick_hook!(hook::Function) = register_hook!(:tick, hook)
register_idle_hook!(hook::Function) = register_hook!(:idle, hook)
register_task_switch_hook!(hook::Function) = register_hook!(:task_switch, hook)
register_malloc_fail_hook!(hook::Function) = register_hook!(:malloc_fail, hook)
register_stack_overflow_hook!(hook::Function) = register_hook!(:stack_overflow, hook)
