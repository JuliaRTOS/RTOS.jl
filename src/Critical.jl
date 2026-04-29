function enter_critical!()
    _KERNEL.runtime_stats["critical_nesting"] =
        get(_KERNEL.runtime_stats, "critical_nesting", 0) + 1
    return _KERNEL.runtime_stats["critical_nesting"]
end

function exit_critical!()
    nesting = get(_KERNEL.runtime_stats, "critical_nesting", 0)
    nesting > 0 || throw(InvalidStateError("critical section is not active"))
    _KERNEL.runtime_stats["critical_nesting"] = nesting - 1
    return _KERNEL.runtime_stats["critical_nesting"]
end

critical_nesting() = get(_KERNEL.runtime_stats, "critical_nesting", 0)

function suspend_scheduler!()
    _KERNEL.runtime_stats["scheduler_suspended"] = true
    return _KERNEL
end

function resume_scheduler!()
    _KERNEL.runtime_stats["scheduler_suspended"] = false
    return _KERNEL
end

scheduler_suspended() = get(_KERNEL.runtime_stats, "scheduler_suspended", false)

function scheduler_can_dispatch()
    return !scheduler_suspended() && critical_nesting() == 0
end
