mutable struct MLDecision
    priorities::Dict{String,Int}
    power_profile::Union{Nothing,String}
    anomalies::Vector{String}
    fault_risks::Dict{String,Float64}
    metadata::Dict{Symbol,Any}
end

function MLDecision(; priorities=Dict{String,Int}(), power_profile=nothing,
                    anomalies=String[], fault_risks=Dict{String,Float64}(),
                    metadata=Dict{Symbol,Any}())
    return MLDecision(_string_int_dict(priorities),
                      power_profile === nothing ? nothing : String(power_profile),
                      _string_vector(anomalies),
                      _string_float_dict(fault_risks),
                      _metadata_dict(metadata))
end

function register_ml_model(name::AbstractString, model; metadata=Dict{Symbol,Any}(),
                           replace::Bool=false)
    name_s = _validate_name(name, :ml_model)
    haskey(_KERNEL.ml_models, name_s) && !replace &&
        throw(DuplicateResourceError(:ml_model, name_s))
    _KERNEL.ml_models[name_s] = (model=model, metadata=_metadata_dict(metadata))
    return _KERNEL.ml_models[name_s]
end

get_ml_model(name::AbstractString) = get(_KERNEL.ml_models, String(name), nothing)

function ml_features(; include_history::Bool=true)
    summary = analytics_summary()
    tasks = Dict{String,Any}()
    for task in values(_KERNEL.tasks)
        tasks[task.name] = (priority=task.priority,
                            effective_priority=task.effective_priority,
                            state=task.state,
                            run_count=task.run_count,
                            notifications=task.notifications,
                            waiting_on=task.waiting_on,
                            deadline_ms=task.deadline_ms,
                            period_ms=task.period_ms,
                            last_error=task.last_error === nothing ? nothing : string(task.last_error))
    end
    queues = Dict{String,Any}()
    for queue in values(_KERNEL.queues)
        queues[queue.name] = (length=length(queue.buffer),
                              capacity=queue.capacity,
                              dropped=queue.dropped,
                              send_waiters=length(queue.send_waiters),
                              receive_waiters=length(queue.receive_waiters))
    end
    resources = latest_resources()
    history = include_history ? resource_history() : ResourceSnapshot[]
    return Dict{Symbol,Any}(:summary => summary,
                            :tasks => tasks,
                            :queues => queues,
                            :resources => resources,
                            :resource_history => history,
                            :events => event_counts(),
                            :clock_ms => _KERNEL.clock_ms)
end

function evaluate_ml_model(model_name::AbstractString; features=ml_features())
    entry = get_ml_model(model_name)
    entry === nothing && throw(ResourceNotFoundError(:ml_model, String(model_name)))
    model = entry.model
    raw = model isa Function ? model(features) : model
    decision = _ml_decision(raw)
    record_event!(:ml, "evaluate"; metadata=Dict(:model => String(model_name),
                                                 :decision => decision))
    return decision
end

function adapt_scheduler!(model_name::AbstractString; features=ml_features())
    decision = evaluate_ml_model(model_name; features=features)
    !isempty(decision.priorities) && rebalance_priorities!(decision.priorities)
    record_event!(:ml, "adapt_scheduler"; metadata=Dict(:model => String(model_name),
                                                        :priorities => decision.priorities))
    return decision
end

function optimize_power!(model_name::AbstractString; features=ml_features())
    decision = evaluate_ml_model(model_name; features=features)
    if decision.power_profile !== nothing
        set_power_profile!(decision.power_profile)
    end
    record_event!(:ml, "optimize_power"; metadata=Dict(:model => String(model_name),
                                                       :profile => decision.power_profile))
    return decision
end

function predict_faults(model_name::AbstractString; features=ml_features(),
                        threshold::Real=0.75)
    decision = evaluate_ml_model(model_name; features=features)
    risky = String[]
    for (task, risk) in decision.fault_risks
        risk >= Float64(threshold) && push!(risky, task)
    end
    record_event!(:ml, "predict_faults"; metadata=Dict(:model => String(model_name),
                                                       :risky_tasks => risky))
    return risky
end

function detect_anomaly(model_name::AbstractString; features=ml_features())
    decision = evaluate_ml_model(model_name; features=features)
    result = !isempty(decision.anomalies) ? decision.anomalies :
             String[String(key) for (key, value) in decision.fault_risks if value >= 0.75]
    record_event!(:ml, "detect_anomaly"; metadata=Dict(:model => String(model_name),
                                                       :result => result))
    return result
end

function run_ml_cycle!(model_name::AbstractString; features=ml_features(),
                       apply_scheduler::Bool=true, apply_power::Bool=true,
                       fault_threshold::Real=0.75)
    decision = evaluate_ml_model(model_name; features=features)
    if apply_scheduler && !isempty(decision.priorities)
        rebalance_priorities!(decision.priorities)
    end
    if apply_power && decision.power_profile !== nothing
        set_power_profile!(decision.power_profile)
    end
    risky = String[]
    for (task, risk) in decision.fault_risks
        risk >= Float64(fault_threshold) && push!(risky, task)
    end
    record_event!(:ml, "cycle"; metadata=Dict(:model => String(model_name),
                                              :risky_tasks => risky,
                                              :anomalies => decision.anomalies))
    return (decision=decision, risky_tasks=risky, anomalies=decision.anomalies)
end

function _ml_decision(raw)
    raw isa MLDecision && return raw
    if raw isa Dict
        if haskey(raw, :priorities) || haskey(raw, "priorities") ||
           haskey(raw, :power_profile) || haskey(raw, "power_profile") ||
           haskey(raw, :anomalies) || haskey(raw, "anomalies") ||
           haskey(raw, :fault_risks) || haskey(raw, "fault_risks")
            return MLDecision(; priorities=_dict_get(raw, :priorities, Dict{String,Int}()),
                              power_profile=_dict_get(raw, :power_profile, nothing),
                              anomalies=_dict_get(raw, :anomalies, String[]),
                              fault_risks=_dict_get(raw, :fault_risks, Dict{String,Float64}()),
                              metadata=_dict_get(raw, :metadata, Dict{Symbol,Any}()))
        end
        return MLDecision(; priorities=_string_int_dict(raw))
    end
    if raw isa Bool
        return raw ? MLDecision(; anomalies=["model signaled anomaly"]) : MLDecision()
    end
    if raw isa AbstractString
        return MLDecision(; anomalies=[String(raw)])
    end
    return MLDecision()
end

function _dict_get(dict::Dict, key::Symbol, default)
    haskey(dict, key) && return dict[key]
    key_s = String(key)
    haskey(dict, key_s) && return dict[key_s]
    return default
end

function _string_int_dict(values)
    result = Dict{String,Int}()
    for (key, value) in values
        result[String(key)] = Int(value)
    end
    return result
end

function _string_float_dict(values)
    result = Dict{String,Float64}()
    for (key, value) in values
        result[String(key)] = Float64(value)
    end
    return result
end

function _string_vector(values)
    values isa AbstractString && return [String(values)]
    return String[String(item) for item in values]
end
