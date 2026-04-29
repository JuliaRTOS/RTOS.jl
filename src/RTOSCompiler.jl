import StaticCompiler

static_compile_available() = true

"""
    compile_rtos(entry, argtypes...; output_dir=pwd(), name=nothing, kind=:executable, kwargs...)

Compile a statically compilable Julia entry point with `StaticCompiler.jl`.

`kind` may be `:executable` or `:library`. `argtypes` are the argument types for
the entry point and are converted to StaticCompiler's tuple-of-types convention.
The return value is whatever `StaticCompiler.compile_executable` or
`StaticCompiler.compile_shlib` returns, normally the produced artifact path.
"""
function compile_rtos(entry::Function, argtypes::Type...;
                      output_dir::AbstractString=pwd(),
                      output::Union{Nothing,AbstractString}=nothing,
                      name::Union{Nothing,AbstractString}=nothing,
                      kind::Symbol=:executable,
                      kwargs...)
    out_dir = output === nothing ? String(output_dir) : String(output)
    mkpath(out_dir)
    signature = Tuple(argtypes)
    if kind == :executable
        return _compile_executable(entry, signature, out_dir, name; kwargs...)
    elseif kind in (:library, :shlib, :shared_library)
        return _compile_library(entry, signature, out_dir, name; kwargs...)
    else
        throw(InvalidStateError("unsupported static compilation kind: $(kind)"))
    end
end

function compile_rtos_executable(entry::Function, argtypes::Type...;
                                 output_dir::AbstractString=pwd(),
                                 output::Union{Nothing,AbstractString}=nothing,
                                 name::Union{Nothing,AbstractString}=nothing,
                                 kwargs...)
    return compile_rtos(entry, argtypes...; output_dir=output_dir, output=output,
                        name=name,
                        kind=:executable, kwargs...)
end

function compile_rtos_library(entry::Function, argtypes::Type...;
                              output_dir::AbstractString=pwd(),
                              output::Union{Nothing,AbstractString}=nothing,
                              name::Union{Nothing,AbstractString}=nothing,
                              kwargs...)
    return compile_rtos(entry, argtypes...; output_dir=output_dir, output=output,
                        name=name,
                        kind=:library, kwargs...)
end

function _compile_executable(entry::Function, signature::Tuple,
                             output_dir::AbstractString,
                             name::Union{Nothing,AbstractString}; kwargs...)
    if name === nothing
        return StaticCompiler.compile_executable(entry, signature, output_dir; kwargs...)
    end
    return StaticCompiler.compile_executable(entry, signature, output_dir, String(name); kwargs...)
end

function _compile_library(entry::Function, signature::Tuple,
                          output_dir::AbstractString,
                          name::Union{Nothing,AbstractString}; kwargs...)
    if name === nothing
        return StaticCompiler.compile_shlib(entry, signature, output_dir; kwargs...)
    end
    return StaticCompiler.compile_shlib(entry, signature, output_dir, String(name); kwargs...)
end
