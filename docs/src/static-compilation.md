```@meta
CurrentModule = RTOS
```

# Static Compilation

`StaticCompiler.jl` is a hard dependency. RTOS.jl exposes a small wrapper around
StaticCompiler's executable and shared-library entry points.

## Direct Compilation

```julia
using RTOS

rtos_main() = 0

compile_rtos_executable(rtos_main; output_dir="build", name="rtos_main")
compile_rtos_library(rtos_main; output_dir="build", name="librtos_main")
```

For arguments, pass concrete argument types:

```julia
control_step(input::Int32) = input + Int32(1)

compile_rtos_library(control_step, Int32; output_dir="build", name="control_step")
```

## Build Targets

Build targets capture artifact metadata and validation:

```julia
register_port!("host"; cores=1)
register_board!("host-board"; port="host")

target = create_build_target(
    "firmware",
    rtos_main;
    board="host-board",
    artifact_kind=:executable,
    output_dir="build",
)

build_plan("firmware")
```

`build_firmware("firmware")` validates the target and invokes the static
compiler wrapper.

For a friendlier application workflow:

```julia
initialize_rtos!(config=RTOSConfig(; tickless=true), port="host", board="host-board")
create_app_task("control", () -> :done; priority=10, period_ms=10, deadline_ms=5, wcet_ms=2)
system_report()
```

## StaticCompiler Constraints

StaticCompiler works best with a restricted subset of Julia:

- concrete primitive argument and return types
- no heap allocation on the compiled boundary
- small entry points
- explicit data layout
- no dynamic dispatch in critical compiled paths

The host kernel model is broader than the statically compiled target subset.
Use the platform layer to model, validate, and narrow the deployment boundary.
