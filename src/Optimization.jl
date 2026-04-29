function optimize_system(objective::Function; package::AbstractString="Optimization",
                         candidates=Any[], kwargs...)
    require_integration(package, "system optimization")
    best = nothing
    best_score = nothing
    for candidate in candidates
        score = objective(candidate)
        if best_score === nothing || score < best_score
            best = candidate
            best_score = score
        end
    end
    return (best=best, score=best_score, kwargs=kwargs)
end
