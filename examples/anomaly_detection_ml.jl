using RTOS

reset_kernel!()

create_queue("uplink", 2)
create_task("radio", () -> :yield, 4; repeat=true)

send_message("uplink", :packet_1)
send_message("uplink", :packet_2)
send_message("uplink", :packet_3; overwrite=true)

register_ml_model("queue-health", function (features)
    anomalies = String[]
    risks = Dict{String,Float64}()

    for (name, queue) in features[:queues]
        if queue.dropped > 0
            push!(anomalies, string(name, " dropped messages"))
            risks["radio"] = 0.85
        end
    end

    return MLDecision(; anomalies=anomalies, fault_risks=risks)
end)

println("anomalies = ", detect_anomaly("queue-health"))
println("fault predictions = ", predict_faults("queue-health"; threshold=0.8))
