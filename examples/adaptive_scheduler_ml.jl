using RTOS

reset_kernel!()
configure!(RTOSConfig(; time_slicing=true))

create_queue("sensor_samples", 4)

create_task("controller", function ()
    receive_message("sensor_samples"; default=nothing)
    return :yield
end, 4; repeat=true)

create_task("telemetry", function ()
    send_message("sensor_samples", (:temp, 22.0); overwrite=true)
    return :yield
end, 3; repeat=true)

register_ml_model("backlog-aware", function (features)
    queue = features[:queues]["sensor_samples"]
    if queue.length >= 2
        return MLDecision(; priorities=Dict("controller" => 9, "telemetry" => 3),
                          anomalies=["sensor backlog building"],
                          metadata=Dict(:reason => :queue_pressure))
    end
    return MLDecision(; priorities=Dict("controller" => 4, "telemetry" => 3))
end)

send_message("sensor_samples", :a)
send_message("sensor_samples", :b)

decision = adapt_scheduler!("backlog-aware")
println("decision priorities = ", decision.priorities)
println("controller priority = ", get_task("controller").priority)

start_scheduler(; max_ticks=4, tick_ms=1, until_idle=false)
println("queue length = ", queue_length("sensor_samples"))
