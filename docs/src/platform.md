```@meta
CurrentModule = RTOS
```

# Platform Layer

The platform layer turns kernel primitives into a more complete engineering
system.

## Friendly Startup

For applications, `initialize_rtos!` gives a single entry point for resetting
the kernel, applying config, registering a port/board, and starting the daemon:

```julia
initialize_rtos!(
    config=RTOSConfig(; max_tasks=32, tickless=true),
    port="host",
    board="devkit",
)

create_app_task(
    "control",
    () -> :done;
    priority=10,
    period_ms=10,
    deadline_ms=5,
    wcet_ms=2,
)

run_rtos!(; max_ticks=100)
```

`system_report()` collects configuration, registry, analytics,
schedulability, and security status into one summary.

## Configuration

`RTOSConfig` defines runtime policy:

```julia
config = RTOSConfig(;
    max_priorities=32,
    tick_rate_hz=1000,
    tickless=true,
    allocation_policy=:hybrid,
    allow_dynamic_allocation=true,
    deterministic_only=false,
    max_tasks=64,
)

configure!(config)
```

`validate_config` returns validation problems without mutating kernel state.
`configure!` applies the config or throws `InvalidStateError`.

## Tickless Planning

`plan_tickless_idle` computes the next wakeup point from ready tasks, blocked
timeouts, timers, and watchdogs:

```julia
plan = plan_tickless_idle()
plan.sleep_ms
```

This is the policy surface for low-power ports.

## Real-Time Contracts

Contracts describe timing assumptions:

```julia
create_task("control", () -> :done, 10)

set_task_contract!(
    "control";
    period_ms=10,
    deadline_ms=5,
    wcet_ms=2,
    jitter_ms=1,
    criticality=:high,
)

schedulability_report()
```

The report includes total utilization and a list of contract violations.

## Security Model

Security modeling is portable and can later be mapped to MPU/TrustZone:

```julia
create_task("driver", () -> :done, 5; metadata=Dict(:privileged => true))

grant_capability!("driver", "privileged")
define_memory_region!("sram", 0x20000000, 4096; permissions=Set([:read, :write]))
assign_region!("driver", "sram")

validate_security()
```

## BSP Lifecycle

Board support packages provide lifecycle hooks:

```julia
register_port!("host"; cores=2)

register_board!(
    "devkit";
    port="host",
    start=board -> println("starting $(board.name)"),
)

start_board!("devkit")
```
