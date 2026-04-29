function control_step(controller::Function, state, input; package::AbstractString="ControlSystems", kwargs...)
    if integration_available(package)
        return controller(state, input; kwargs...)
    end
    return controller(state, input)
end
