using RTOS

reset_kernel!()
configure!(RTOSConfig(; tick_rate_hz=1000, time_slicing=true))

events = String[]

create_queue("sensor_queue", 3)
create_binary_semaphore("sample_ready"; available=false)
create_event_group("system_flags")

create_task("producer", function ()
    send_message("sensor_queue", (:temperature, 22.5))
    give_semaphore("sample_ready")
    set_event_bits!("system_flags", 0x01)
    push!(events, "producer")
    return :done
end, 3)

create_task("consumer", function ()
    if take_semaphore("sample_ready", "consumer")
        sample = receive_message("sensor_queue")
        push!(events, string("consumer:", sample))
    end
    return :done
end, 2)

create_timer("heartbeat", 5, _ -> push!(events, "heartbeat"); autostart=true)

start_scheduler(; max_ticks=3, tick_ms=5, until_idle=false)

println("events = ", events)
println("queue spaces = ", queue_spaces_available("sensor_queue"))
println("flags = ", get_event_bits("system_flags"))
