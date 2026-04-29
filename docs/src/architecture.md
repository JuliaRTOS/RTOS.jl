```@meta
CurrentModule = RTOS
```

# Architecture

RTOS.jl is organized into layers so the deterministic real-time core remains
small and predictable while higher-level platform features can evolve around it.

## Deterministic Core

The core layer contains the FreeRTOS-like primitives:

- tasks, priorities, delays, task notifications, and lifecycle management
- priority scheduling with deadline tie-breaking
- queues, queue sets, event groups, stream buffers, and message buffers
- mutexes, recursive mutexes, binary semaphores, and counting semaphores
- timers, watchdogs, interrupt handlers, and ISR-safe APIs
- static-init APIs for caller-owned kernel objects
- hooks for tick, idle, task switch, malloc failure, and stack overflow

The core is intentionally deterministic. The same task priorities, deadlines,
release times, and events should produce the same host-side dispatch sequence.

## Observability And Operations

The operations layer makes the kernel inspectable:

- event logging and trace records
- runtime stats and Chrome trace export
- resource snapshots
- analytics summaries
- runtime configuration
- power profiles
- fault policies
- shared caches and task pools

These features are useful both for development and for building automated
validation around real-time behavior.

## Platform Layer

The platform layer adds system-level guarantees:

- `RTOSConfig` for scheduler, allocation, and deterministic-mode policy
- `TicklessPlan` for event-driven sleep planning
- `TaskContract` for period, deadline, WCET, jitter, and criticality metadata
- schedulability reports and utilization accounting
- capability and memory-region security modeling
- board support package lifecycle hooks
- named static build targets
- kernel registry and object snapshots
- daemon service command processing
- heap strategy models
- task-local storage
- safety profile validation
- network and OTA adapter interfaces

The platform layer is the intended boundary for board-specific and
architecture-specific implementations.

## Adaptive Layer

RTOS.jl includes adapter boundaries for ML, optimization, control, and system
modeling. These adapters accept local callable models today and can connect to
packages such as MLJ, ModelingToolkit, Optimization, and ControlSystems when
those packages are available in the active environment.

Only `StaticCompiler.jl` is a hard dependency. The ML/SciML ecosystem moves
faster than Julia 1.0 compatibility, so these integrations are deliberately
optional boundaries.
