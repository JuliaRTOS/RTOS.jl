```@meta
CurrentModule = RTOS
```

# System Services

System services provide the operational pieces that make the kernel easier to
debug, audit, and integrate.

## Kernel Registry

```julia
reset_kernel!()
create_task("control", () -> :done, 5)
create_queue("events", 4)

kernel_registry()
find_kernel_object(:task, "control")
kernel_snapshot()
```

## Daemon Service

The daemon service processes deferred command callbacks outside ISR paths.

```julia
start_daemon!()

post_daemon_command!(:flush_logs, () -> clear_logs!())

process_daemon_commands!()
```

The scheduler also services daemon commands between ticks.

## Heap Schemes

RTOS.jl includes FreeRTOS-inspired heap strategy models:

```julia
create_heap!("boot", :heap1, 1024)
create_heap!("general", :heap4, 4096)
create_heap!("regions", :region, 0; regions=[("fast", 512), ("slow", 2048)])

block = heap_alloc!("general", 128)
heap_free!("general", block)
heap_stats("general")
```

## Task-Local Storage

```julia
create_task("sensor", () -> :done, 3)
set_task_local!("sensor", :device, "imu0")
get_task_local("sensor", :device)
delete_task_local!("sensor", :device)
```

## Safety Profiles

```julia
configure!(RTOSConfig(; allow_dynamic_allocation=false, allocation_policy=:static))

create_task("critical", () -> :done, 10)
set_task_contract!("critical"; period_ms=10, deadline_ms=5, wcet_ms=2)
define_memory_region!("sram", 0x20000000, 4096)
assign_region!("critical", "sram")

create_safety_profile("strict"; require_memory_regions=true)
safety_report("strict")
```

## Network Interfaces

Network interfaces are adapters. RTOS.jl defines the lifecycle and API; actual
stacks can live in separate packages or board support packages.

```julia
register_network_interface!(
    "net0";
    send=payload -> length(payload),
    receive=() -> UInt8[],
    status=() -> :up,
)

network_send!("net0", UInt8[0x01, 0x02])
network_status("net0")
```

## OTA Updates

```julia
register_ota_updater!(
    "ota";
    stage=artifact -> (artifact=artifact, staged=true),
    verify=staged -> staged.staged,
    apply=staged -> staged.artifact,
)

stage_update!("ota", "firmware.bin")
verify_update!("ota")
apply_update!("ota")
```
