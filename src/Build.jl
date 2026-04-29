mutable struct RTOSBuildTarget
    name::String
    entry::Function
    argtypes::Tuple
    board::Union{Nothing,String}
    output_dir::String
    artifact_kind::Symbol
    static_audit::Bool
end

function create_build_target(name::AbstractString, entry::Function, argtypes::Type...;
                             board=nothing, output_dir::AbstractString="build",
                             artifact_kind::Symbol=:executable,
                             static_audit::Bool=true)
    name_s = _validate_name(name, :build_target)
    haskey(_KERNEL.build_targets, name_s) &&
        throw(DuplicateResourceError(:build_target, name_s))
    target = RTOSBuildTarget(name_s, entry, Tuple(argtypes),
                             board === nothing ? nothing : String(board),
                             String(output_dir), artifact_kind, static_audit)
    _KERNEL.build_targets[name_s] = target
    return target
end

function validate_build_target(target::RTOSBuildTarget)
    problems = String[]
    target.artifact_kind in (:executable, :library) ||
        push!(problems, "artifact_kind must be :executable or :library")
    if target.board !== nothing && !haskey(_KERNEL.boards, target.board)
        push!(problems, "unknown board $(target.board)")
    end
    target.static_audit && !isempty(validate_security()) &&
        push!(problems, "security validation failed")
    return problems
end

function build_plan(name::AbstractString)
    target = get(_KERNEL.build_targets, String(name), nothing)
    target === nothing && throw(ResourceNotFoundError(:build_target, String(name)))
    problems = validate_build_target(target)
    return (target=target.name, output_dir=target.output_dir,
            artifact_kind=target.artifact_kind, board=target.board,
            valid=isempty(problems), problems=problems)
end

function build_target!(name::AbstractString; force::Bool=false)
    target = get(_KERNEL.build_targets, String(name), nothing)
    target === nothing && throw(ResourceNotFoundError(:build_target, String(name)))
    problems = validate_build_target(target)
    if !isempty(problems) && !force
        throw(InvalidStateError(join(problems, "; ")))
    end
    if target.artifact_kind == :executable
        return compile_rtos_executable(target.entry, target.argtypes...;
                                       output_dir=target.output_dir,
                                       name=target.name)
    elseif target.artifact_kind == :library
        return compile_rtos_library(target.entry, target.argtypes...;
                                    output_dir=target.output_dir,
                                    name=target.name)
    end
    throw(InvalidStateError("unsupported artifact_kind: $(target.artifact_kind)"))
end

build_firmware(name::AbstractString; force::Bool=false) =
    build_target!(name; force=force)
