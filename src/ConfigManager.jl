function set_config!(key::Symbol, value)
    _KERNEL.config[key] = value
    record_event!(:config, String(key); metadata=Dict(:value => value))
    return value
end

get_config(key::Symbol, default=nothing) = get(_KERNEL.config, key, default)

function load_config!(config::Dict)
    for (key, value) in config
        set_config!(Symbol(key), value)
    end
    return config_snapshot()
end

config_snapshot() = copy(_KERNEL.config)
