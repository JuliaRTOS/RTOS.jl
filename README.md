# RTOS.jl

RTOS.jl is a Julia-native real-time operating system toolkit and deterministic
kernel simulator. It provides the RTOS building blocks you expect from FreeRTOS,
plus Julia-friendly scheduling, observability, memory accounting, and static
compilation hooks for embedded experiments.

This package is not a drop-in replacement for a hardware kernel yet. Today it is
most useful for modeling, testing, and prototyping real-time application logic in
Julia before moving selected entry points toward embedded/static builds.

## Features

- Priority scheduler with deadline tie-breaking and repeatable simulation ticks
- Periodic task releases through `period_ms`
- Local periodic task scheduler for named periodic jobs
- Task lifecycle management: create, suspend, resume, stop, delete, notify
- Task delays and timeout-based unblocking
- IPC message queues with bounded capacity, overwrite mode, peek, reset,
  spaces-available, and blocking waiter metadata
- Queue sets for waiting across multiple synchronization objects
- ISR-safe queue, semaphore, notification, and deferred-callback APIs
- Local ring buffer implementation for deterministic bounded buffering
- Event groups with wait-any and wait-all bit semantics
- Stream buffers and message buffers
- Fixed-block pools and bounded dynamic allocators
- Timers with one-shot, periodic, reset, period-change, fire-count, and
  daemon-pended command modes
- Interrupt registration/dispatch
- Driver registry with read/write/control hooks
- Mutexes with priority inheritance, recursive mode, and deadlock prevention
- Binary and counting semaphores
- Watchdog timers and structured in-memory logging
- Event logging, analytics summaries, runtime configuration, resource snapshots
- Task pools, shared caches, power profiles, load balancing, and fault policies
- ML/adaptive operations hooks with callable model adapters, typed decisions,
  feature extraction, priority tuning, power-profile selection, anomaly
  detection, and fault-risk prediction
- Direct-to-task notification actions: increment, set-bits, overwrite, and
  no-overwrite
- Critical-section and scheduler-suspension APIs
- Configurable equal-priority time slicing
- FreeRTOS-style hooks: tick, idle, task switch, malloc fail, stack overflow
- Port and core-affinity model for BSP/SMP work
- Static-init APIs for caller-owned kernel objects
- Runtime stats and trace export
- Production configuration, tickless planning, real-time contracts,
  capability security, BSP lifecycle, and one-command build targets
- Kernel registry, daemon command service, task-local storage, safety profiles,
  FreeRTOS-inspired heap schemes, network adapters, and OTA update adapters
- Required `StaticCompiler.jl` integration for native executable and shared
  library builds

## Production Posture

RTOS.jl is designed to be strict by default:

- Duplicate resource names throw typed `DuplicateResourceError`s instead of
  silently replacing live kernel objects.
- Invalid lifecycle, timing, priority, and capacity inputs throw typed RTOS
  exceptions.
- Simulation time is monotonic; negative ticks are rejected.
- Periodic tasks are only released after their configured period.
- Mutex deadlock detection is kernel-wide, not limited to a single lock.
- The scheduler is deterministic: effective priority, deadline, and creation
  order define dispatch order.

The package currently provides a production-grade host-side RTOS model and API
surface. Hardware preemption, interrupt vectors, MMU/MPU integration, and board
support packages remain target-specific work.

## Platform Layer

RTOS.jl includes production-platform services beyond FreeRTOS-style primitives:

- `RTOSConfig` validates scheduler, allocation, deterministic-mode, and feature
  policy before runtime.
- `TicklessPlan` computes the next wakeup and sleep budget for event-driven
  scheduling.
- `TaskContract` captures period, deadline, WCET, jitter, and criticality for
  schedulability reports.
- `Capability` and `MemoryRegion` model MPU-style access control before a
  hardware port enforces it.
- `BoardSupportPackage` provides board lifecycle hooks.
- `RTOSBuildTarget` plus `build_firmware` validates and invokes the static
  compiler wrapper for a named artifact.
- `kernel_registry` and `kernel_snapshot` expose all named kernel objects for
  diagnostics and tooling.
- `SafetyProfile` produces deployment-readiness reports for stricter systems.
- Network and OTA adapters define platform interfaces without forcing a
  particular TCP/IP, TLS, cloud, or storage stack into the kernel.

## Architecture

RTOS.jl separates the system into three layers:

- Deterministic core: tasks, scheduler, IPC, memory, timers, interrupts, sync,
  safety, drivers, ring buffers, event groups, queue sets, stream/message
  buffers, ISR-safe APIs, hooks, static initialization, and periodic jobs.
- Observability and operations: event logging, analytics, configuration,
  resource monitoring, power profiles, load balancing, task pools, shared
  caches, and fault policies.
- Adaptive integrations: ML/SciML/control adapters that accept local callable
  models today and can connect to packages such as MLJ, ModelingToolkit,
  Optimization, and ControlSystems when those packages are available in the
  active environment.

Only `StaticCompiler.jl` is a hard external dependency. The broader ML/SciML
ecosystem evolves faster than Julia 1.0 compatibility, so those integrations are
implemented as explicit adapter boundaries instead of mandatory dependencies.
That keeps the RTOS core buildable across the widest Julia 1.x range while still
providing clean hooks for adaptive scheduling, anomaly detection, modeling, and
optimization.

## FreeRTOS Parity

RTOS.jl now includes Julia-native equivalents for the core FreeRTOS kernel
surface: tasks, priorities, queues, semaphores, mutexes, recursive mutex
support, task notifications, event groups, queue sets, stream/message buffers,
software timers, ISR-safe APIs, hooks, static allocation/init APIs, runtime
stats, trace events, stack budget metadata, and a port/core-affinity abstraction.

The remaining work is hardware-port work rather than host-kernel API work:
real CPU context switching, MCU interrupt priority registers, MPU/TrustZone
configuration, hardware tick suppression, and board-specific startup/BSP code.
Those belong behind the `PortConfig`/driver layers so the deterministic host
model and static-compiled target code stay aligned.

## Replicable Examples

The `examples/` directory contains complete scripts that can be run from the
package root:

```bash
julia --project=. examples/freertos_parity_demo.jl
julia --project=. examples/control_loop_with_safety.jl
julia --project=. examples/queue_and_timer_commands.jl
julia --project=. examples/static_build_plan.jl
julia --project=. examples/adaptive_scheduler_ml.jl
julia --project=. examples/power_fault_ml.jl
julia --project=. examples/anomaly_detection_ml.jl
```

## Quick Start

```julia
using RTOS

reset_kernel!()

create_task("telemetry", () -> println("sample sensors"), 5)
create_task("control", () -> println("update actuator"), 10; deadline_ms=5)

start_scheduler()
```

## Synchronization

```julia
using RTOS

reset_kernel!()
create_task("low", () -> nothing, 1)
create_task("high", () -> nothing, 9)

create_mutex("i2c")
lock_mutex("i2c", "low")
lock_mutex("i2c", "high"; block=true) # boosts low to high's priority
unlock_mutex("i2c", "low")            # wakes high and transfers ownership
```

## Timers And Watchdogs

```julia
using RTOS

reset_kernel!()

create_timer("heartbeat", 100, timer -> println(timer.fire_count); autostart=true)
create_watchdog("main", 250)

tick!(100)
feed_watchdog("main")
tick!(250)

@assert watchdog_expired("main")
```

## Static Compilation

`StaticCompiler.jl` is a hard dependency of RTOS.jl. That means installation
will resolve the compiler up front, and RTOS.jl exposes a small wrapper around
StaticCompiler's executable and shared-library entry points. Entry points must
still follow StaticCompiler's constraints: prefer concrete primitive argument and
return types, avoid heap allocation, and keep the compiled boundary small.

RTOS.jl intentionally keeps broad compatibility: the package declares support
for Julia `1.x` starting at Julia 1.0 and accepts StaticCompiler `0.x` and `1.x`
releases. CI is configured to test every Julia minor release from 1.0 through
the current stable line, plus prerelease/nightly Julia.

```julia
using RTOS

rtos_main() = 0

compile_rtos_executable(rtos_main; output_dir="build", name="rtos_main")
compile_rtos_library(rtos_main; output_dir="build", name="librtos_main")
```

For functions with arguments, pass the argument types after the function:

```julia
control_step(input::Int32) = input + Int32(1)

compile_rtos_library(control_step, Int32; output_dir="build", name="control_step")
```

## Testing

Run the full test suite from a Julia-enabled environment:

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

or:

```bash
julia --project=. test/runtests.jl
```
