function integration_available(package::AbstractString)
    return Base.find_package(String(package)) !== nothing
end

function require_integration(package::AbstractString, feature::AbstractString)
    integration_available(package) || throw(IntegrationUnavailableError(String(package), String(feature)))
    return true
end

function system_model(; package::AbstractString="ModelingToolkit", kwargs...)
    require_integration(package, "system modeling")
    return (package=String(package), clock_ms=_KERNEL.clock_ms,
            tasks=length(_KERNEL.tasks), kwargs=kwargs)
end
