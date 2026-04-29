```@meta
CurrentModule = RTOS
```

# Examples

All examples below are complete scripts in the repository and can be run from
the package root:

```sh
julia --project=. examples/freertos_parity_demo.jl
julia --project=. examples/control_loop_with_safety.jl
julia --project=. examples/queue_and_timer_commands.jl
julia --project=. examples/static_build_plan.jl
julia --project=. examples/adaptive_scheduler_ml.jl
julia --project=. examples/power_fault_ml.jl
julia --project=. examples/anomaly_detection_ml.jl
```

## Replicable Scripts

| Example | What it demonstrates |
| --- | --- |
| `examples/freertos_parity_demo.jl` | tasks, queues, binary semaphores, event groups, timers, and scheduler ticks |
| `examples/control_loop_with_safety.jl` | periodic control loop, watchdog feeding, safety profile reporting |
| `examples/queue_and_timer_commands.jl` | queue peek/spaces, daemon-pended timer commands, timer fire counts |
| `examples/static_build_plan.jl` | StaticCompiler availability and RTOS build target planning |
| `examples/adaptive_scheduler_ml.jl` | backlog-aware priority tuning with an ML policy |
| `examples/power_fault_ml.jl` | power profile switching plus task fault-risk prediction |
| `examples/anomaly_detection_ml.jl` | queue-drop anomaly detection and predictive fault signals |

Use these as smoke tests when changing APIs. They intentionally avoid optional
ML/SciML packages so they remain easy to reproduce on a fresh Julia project.

## Event Group

```julia
reset_kernel!()

create_task("waiter", () -> :done, 1)
create_event_group("flags")

wait_event_bits("flags", 0x03, "waiter"; wait_all=true)
set_event_bits!("flags", 0x01)
set_event_bits!("flags", 0x02)
```

## Stream Buffer

```julia
reset_kernel!()

create_stream_buffer("uart_rx", 64)
stream_send!("uart_rx", UInt8[0x41, 0x42])
stream_receive!("uart_rx", 2)
```

## Queue Set

```julia
reset_kernel!()

create_queue("events", 4)
create_binary_semaphore("ready"; available=false)
create_queue_set("wait_any")

add_to_queue_set!("wait_any", :queue, "events")
add_to_queue_set!("wait_any", :semaphore, "ready")

send_message("events", :boot)
select_from_queue_set("wait_any")
```

## Trace Export

```julia
reset_kernel!()

create_task("work", () -> :done, 5)
start_scheduler()

chrome_trace()
```

The returned string can be saved as JSON and opened in Chrome's tracing viewer.

## Adaptive Scheduling Policy

```julia
reset_kernel!()

create_task("control", () -> :done, 5)

register_ml_model("raise-control", features -> MLDecision(;
    priorities=Dict("control" => 10),
    anomalies=String[],
))

adapt_scheduler!("raise-control")
```

ML models are deliberately callable adapters. They can be simple Julia
functions, generated code, or wrappers around MLJ/SciML models in environments
that install those packages. Heavy ML packages are optional environment choices,
not hard kernel dependencies.

## Full ML Operations Cycle

```julia
reset_kernel!()

create_power_profile("eco"; tick_ms=20, max_active_tasks=1)
create_power_profile("performance"; tick_ms=1, max_active_tasks=8)

create_task("control", () -> :yield, 5; repeat=true)
create_task("telemetry", () -> :yield, 2; repeat=true)

register_ml_model("ops", features -> MLDecision(;
    priorities=Dict("control" => 9, "telemetry" => 2),
    power_profile=features[:summary][:ready_tasks] > 1 ? "performance" : "eco",
    fault_risks=Dict("control" => 0.15),
))

run_ml_cycle!("ops")
```

## Queue and Timer Service Commands

```julia
reset_kernel!()

create_queue("work", 1)
send_message("work", :first)

peek_message("work")
queue_spaces_available("work")

create_timer("poll", 10, _ -> send_message("work", :timer; overwrite=true))
start_daemon!()
pend_timer_command!("poll", :start)
process_daemon_commands!()
```

## Critical Sections

```julia
reset_kernel!()

create_task("control", () -> :done, 5)

enter_critical!()
schedule_once!() === nothing
exit_critical!()
schedule_once!()
```
