mutable struct BoardSupportPackage
    name::String
    port::String
    drivers::Vector{String}
    start::Union{Nothing,Function}
    stop::Union{Nothing,Function}
    reset::Union{Nothing,Function}
    metadata::Dict{Symbol,Any}
end

function register_board!(name::AbstractString; port::AbstractString="host",
                         drivers=String[], start=nothing, stop=nothing,
                         reset=nothing, metadata=Dict{Symbol,Any}())
    name_s = _validate_name(name, :board)
    haskey(_KERNEL.boards, name_s) && throw(DuplicateResourceError(:board, name_s))
    haskey(_KERNEL.ports, String(port)) ||
        throw(ResourceNotFoundError(:port, String(port)))
    board = BoardSupportPackage(name_s, String(port), String[String(driver) for driver in drivers],
                                start, stop, reset, _metadata_dict(metadata))
    _KERNEL.boards[name_s] = board
    set_config!(:board, name_s)
    return board
end

function current_board()
    name = get_config(:board, nothing)
    name === nothing && return nothing
    return get(_KERNEL.boards, String(name), nothing)
end

function start_board!(name::AbstractString)
    board = _require_board(name)
    board.start !== nothing && board.start(board)
    record_event!(:board, "start"; metadata=Dict(:board => board.name))
    return board
end

function stop_board!(name::AbstractString)
    board = _require_board(name)
    board.stop !== nothing && board.stop(board)
    record_event!(:board, "stop"; metadata=Dict(:board => board.name))
    return board
end

function reset_board!(name::AbstractString)
    board = _require_board(name)
    board.reset !== nothing && board.reset(board)
    record_event!(:board, "reset"; metadata=Dict(:board => board.name))
    return board
end

function _require_board(name::AbstractString)
    board = get(_KERNEL.boards, String(name), nothing)
    board === nothing && throw(ResourceNotFoundError(:board, String(name)))
    return board
end
