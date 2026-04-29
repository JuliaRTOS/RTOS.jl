using RTOS

reset_kernel!()

create_power_profile("eco"; tick_ms=20, max_active_tasks=1)
create_power_profile("performance"; tick_ms=1, max_active_tasks=8)

create_task("vision", () -> :yield, 5; repeat=true)
create_task("logger", () -> :yield, 2; repeat=true)

sample_resources!()

register_ml_model("operations-policy", function (features)
    tasks = features[:tasks]
    events = features[:events]
    failed_events = get(events, :fault, 0)
    ready_count = features[:summary][:ready_tasks]

    profile = ready_count > 1 ? "performance" : "eco"
    risks = Dict{String,Float64}()
    risks["vision"] = failed_events > 0 ? 0.9 : 0.2

    priorities = Dict("vision" => profile == "performance" ? 8 : 5,
                      "logger" => 2)

    return MLDecision(; priorities=priorities,
                      power_profile=profile,
                      fault_risks=risks,
                      metadata=Dict(:task_count => length(tasks)))
end)

result = run_ml_cycle!("operations-policy")

println("power profile = ", current_power_profile().name)
println("vision priority = ", get_task("vision").priority)
println("risky tasks = ", result.risky_tasks)
