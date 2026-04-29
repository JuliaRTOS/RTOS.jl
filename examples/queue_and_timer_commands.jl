using RTOS

reset_kernel!()

log = String[]

create_queue("work", 1)
create_task("worker", function ()
    item = receive_message("work"; default=:idle)
    push!(log, string(item))
    return :yield
end, 2; repeat=true)

send_message("work", :first)
println("peek = ", peek_message("work"))
println("spaces before reset = ", queue_spaces_available("work"))

create_timer("poll", 10, _ -> send_message("work", :timer; overwrite=true))
start_daemon!()
pend_timer_command!("poll", :start)
process_daemon_commands!()

start_scheduler(; max_ticks=4, tick_ms=10, until_idle=false)

println("log = ", log)
println("timer fires = ", timer_fire_count("poll"))
