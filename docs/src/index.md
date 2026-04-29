```@meta
CurrentModule = RTOS
```

# RTOS.jl

RTOS.jl is a Julia-native RTOS toolkit, deterministic kernel simulator, and
static-compilation-oriented platform layer. It provides a FreeRTOS-style kernel
surface for tasks, queues, semaphores, mutexes, event groups, timers, ISR-safe
APIs, hooks, static allocation, trace, and runtime stats, then adds Julia-native
platform services for schedulability analysis, tickless planning, security
capabilities, BSP lifecycle, analytics, and adaptive scheduling.

The current implementation is production-oriented for host-side modeling,
testing, and static-build preparation. Hardware preemption, MCU context
switching, interrupt priority registers, MPU/TrustZone enforcement, and
board-specific startup code belong behind the port/BSP layer.

## Compatibility

RTOS.jl targets Julia `1.10` and newer. `StaticCompiler.jl` is a hard
dependency, and the package accepts StaticCompiler `0.x` and `1.x` releases.

## Quick Start

```julia
using RTOS

reset_kernel!()

configure!(RTOSConfig(; tick_rate_hz=1000, tickless=false))

create_app_task("telemetry", () -> :done; priority=5)
create_app_task("control", () -> :done; priority=10, deadline_ms=5, wcet_ms=2)

ran = run_rtos!()
```

## Manual

```@contents
Pages = [
    "architecture.md",
    "freertos-parity.md",
    "platform.md",
    "system-services.md",
    "static-compilation.md",
    "examples.md",
    "api.md",
]
Depth = 2
```
