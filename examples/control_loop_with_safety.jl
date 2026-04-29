using RTOS

reset_kernel!()
initialize_rtos!(; config=RTOSConfig(; max_tasks=8, tickless=false,
                                    allow_dynamic_allocation=false,
                                    allocation_policy=:static),
                 port="host", board="host-sim")

create_safety_profile("demo"; require_contracts=false)

create_watchdog("main_watchdog", 25)
create_queue("commands", 4)

state = Dict(:position => 0, :target => 3)

create_periodic_task("controller", function ()
    state[:position] += 1
    send_message("commands", (:move, state[:position]); overwrite=true)
    feed_watchdog("main_watchdog")
    return state[:position] >= state[:target] ? :done : :yield
end, 5, 10)

create_task("actuator", function ()
    command = receive_message("commands"; default=nothing)
    command === nothing || println("actuator command: ", command)
    return :yield
end, 4; repeat=true)

start_periodic_task!("controller")
run_rtos!(; max_ticks=8, tick_ms=5, until_idle=false)

println("safety report = ", safety_report("demo"))
println("system report = ", system_report())
