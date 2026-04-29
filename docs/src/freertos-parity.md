```@meta
CurrentModule = RTOS
```

# FreeRTOS Parity

RTOS.jl implements Julia-native equivalents for the major FreeRTOS kernel
concepts while keeping room for a more analytical and adaptive platform.

## Implemented Kernel Surface

| FreeRTOS area | RTOS.jl support |
| --- | --- |
| Tasks | `create_task`, lifecycle APIs, priorities, delays |
| Scheduler | deterministic priority scheduler with deadline tie-breaks |
| Task notifications | `notify_task`, `take_notification`, ISR variant |
| Direct notification actions | increment, set-bits, overwrite, and no-overwrite semantics |
| Queues | bounded queues with overwrite, peek, reset, spaces-available, and blocking waiter metadata |
| Queue sets | `QueueSet`, `select_from_queue_set` |
| Semaphores | binary and counting semaphores |
| Mutexes | mutexes, recursive mutexes, priority inheritance |
| Event groups | bitmask event groups, wait-all/wait-any |
| Stream buffers | bounded byte stream buffers |
| Message buffers | bounded variable-size message buffers |
| Timers | one-shot and periodic timers, reset, period change, fire counts, daemon-pended commands |
| Watchdogs | watchdog creation, feeding, expiry checks |
| ISR APIs | ISR-safe queue/semaphore/notification helpers |
| Deferred ISR work | deferred callback queue |
| Hooks | tick, idle, task switch, malloc fail, stack overflow |
| Critical sections | critical nesting and scheduler suspension APIs |
| Time slicing | configurable equal-priority round-robin behavior |
| Static allocation | init APIs for caller-owned objects |
| Runtime stats | task runs, events, resource summaries |
| Trace | event trace and Chrome trace export |
| Port model | port config, core count, task affinity |
| Daemon task | daemon command service for deferred work |
| Heap schemes | `heap1`, `heap2`, `heap4`, and region heap models |
| Task local storage | typed task-local key/value storage |
| Queue registry | unified `kernel_registry` and snapshots |

## Hardware-Specific Work

The following are modeled but not yet enforced by real MCU hardware:

- CPU context switching
- interrupt priority registers and nesting enforcement
- MPU/TrustZone configuration
- hardware tick suppression
- architecture startup code
- board-specific linker scripts and peripheral initialization

These belong in board support packages and architecture ports.

## Newly Closed Gaps

The most important remaining FreeRTOS convenience APIs are now modeled:

- `queue_spaces_available`, `peek_message`, and `reset_queue!` cover the common queue introspection operations.
- `send_message(...; block=true, task_name="task")` and `receive_message(...; block=true, task_name="task")` record blocked queue waiters and wake them when capacity or data appears.
- `notify_task_value(...; action=:increment | :set_bits | :overwrite | :no_overwrite)` maps the direct-to-task notification modes into one Julia API.
- `enter_critical!`, `exit_critical!`, `suspend_scheduler!`, and `resume_scheduler!` model critical sections and scheduler lockout.
- `reset_timer!`, `change_timer_period!`, `timer_fire_count`, and `pend_timer_command!` fill in the timer service behavior expected by FreeRTOS users.
- `RTOSConfig(; time_slicing=true)` enables round-robin dispatch among equal-priority yielding tasks.

## Where RTOS.jl Can Go Beyond FreeRTOS

RTOS.jl can provide capabilities that are not typical FreeRTOS kernel features:

- schedulability and utilization reports
- trace-first debugging
- host-side deterministic simulation
- adaptive scheduling hooks
- anomaly detection hooks
- system modeling and optimization adapters
- one-command static build target metadata
- security validation before deployment
- safety profile reports
- network and OTA adapter boundaries
