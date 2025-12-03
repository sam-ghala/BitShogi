# board_generator.jl - Generate and save daily puzzles to JSON
# 
# Usage: 
#   include("board_generator.jl")
#   generate_puzzle_file(365, "frontend/public/puzzles.json")
#
# This creates puzzles.json in the frontend/public folder

using Random
using JSON3

# Piece configurations (black_pieces, white_pieces) - SFEN characters
const PUZZLE_PIECE_CONFIGS = [
    # Full armies
    (["G", "S", "B", "R", "P"], ["g", "s", "b", "r", "p"]),
    # No bishops
    (["G", "S", "R", "P", "P"], ["g", "s", "r", "p", "p"]),
    # No rooks  
    (["G", "S", "B", "P", "P"], ["g", "s", "b", "p", "p"]),
    # Heavy pieces only
    (["R", "B"], ["r", "b"]),
    # Gold vs Silver
    (["G", "G", "P", "P"], ["s", "s", "p", "p"]),
    # Minimal generals
    (["G", "S"], ["g", "s"]),
    # Rook battle
    (["R", "G", "P"], ["r", "g", "p"]),
    # Bishop battle
    (["B", "S", "P"], ["b", "s", "p"]),
    # Asymmetric Rook vs Bishop
    (["R", "G", "P"], ["b", "s", "p", "p"]),
    # Pawn army
    (["G", "P", "P", "P"], ["g", "p", "p", "p"]),
    # Double generals
    (["G", "G", "S", "P"], ["g", "g", "s", "p"]),
    # Power pieces
    (["R", "B", "G"], ["r", "b", "g"]),
    # Heavy vs Light
    (["R", "R"], ["g", "s", "p", "p", "p"]),
    # All silvers
    (["S", "S", "P", "P"], ["s", "s", "p", "p"]),
    # No pawns
    (["G", "S", "B", "R"], ["g", "s", "b", "r"]),
]

const PUZZLE_PIECE_VALUES = Dict(
    "P" => 1, "p" => 1, "S" => 5, "s" => 5,
    "G" => 5, "g" => 5, "B" => 8, "b" => 8,
    "R" => 9, "r" => 9, "K" => 0, "k" => 0
)

"""
Check if kings are not adjacent.
"""
function kings_not_adjacent(sq1::Int, sq2::Int)::Bool
    f1, r1 = (sq1 - 1) % 5 + 1, (sq1 - 1) ÷ 5 + 1
    f2, r2 = (sq2 - 1) % 5 + 1, (sq2 - 1) ÷ 5 + 1
    return abs(f1 - f2) > 1 || abs(r1 - r2) > 1
end

"""
Build SFEN from piece placement.
"""
function build_sfen(placement::Dict{Int, String})::String
    ranks = String[]
    for rank in 1:5
        rank_str, empty = "", 0
        for file in 1:5
            sq = (rank - 1) * 5 + file
            if haskey(placement, sq)
                empty > 0 && (rank_str *= string(empty); empty = 0)
                rank_str *= placement[sq]
            else
                empty += 1
            end
        end
        empty > 0 && (rank_str *= string(empty))
        push!(ranks, rank_str)
    end
    return join(ranks, "/") * " b - 1"
end

"""
Calculate occupied squares bitboard from SFEN.
"""
function sfen_to_bitboard(sfen::String)::UInt32
    board_part = split(sfen, " ")[1]
    bb, sq = UInt32(0), 0
    for c in board_part
        c == '+' && continue
        if isdigit(c)
            sq += parse(Int, c)
        elseif c != '/'
            bb |= UInt32(1) << sq
            sq += 1
        end
    end
    return bb
end

"""
Calculate material balance from SFEN.
"""
function puzzle_material_balance(sfen::String)::Int
    black, white = 0, 0
    for c in split(sfen, " ")[1]
        c in ['/', '1', '2', '3', '4', '5', '+'] && continue
        v = get(PUZZLE_PIECE_VALUES, string(c), 0)
        isuppercase(c) ? (black += v) : (white += v)
    end
    return black - white
end

"""
Generate a random puzzle SFEN with given piece config.
"""
function generate_puzzle_sfen(rng::AbstractRNG, black_pieces::Vector{String}, white_pieces::Vector{String})::Union{String, Nothing}
    placement = Dict{Int, String}()
    occupied = Set{Int}()
    
    # Place black king (ranks 3-5)
    bk_candidates = shuffle(rng, [sq for sq in 1:25 if (sq-1) ÷ 5 >= 2])
    isempty(bk_candidates) && return nothing
    bk = bk_candidates[1]
    placement[bk] = "K"
    push!(occupied, bk)
    
    # Place white king (ranks 1-3, not adjacent)
    wk_candidates = shuffle(rng, [sq for sq in 1:25 if (sq-1) ÷ 5 <= 2 && kings_not_adjacent(sq, bk) && !(sq in occupied)])
    isempty(wk_candidates) && return nothing
    wk = wk_candidates[1]
    placement[wk] = "k"
    push!(occupied, wk)
    
    # Place black pieces
    avail = shuffle(rng, [sq for sq in 1:25 if !(sq in occupied)])
    for (i, p) in enumerate(black_pieces)
        i > length(avail) && return nothing
        placement[avail[i]] = p
        push!(occupied, avail[i])
    end
    
    # Place white pieces
    avail = shuffle(rng, [sq for sq in 1:25 if !(sq in occupied)])
    for (i, p) in enumerate(white_pieces)
        i > length(avail) && return nothing
        placement[avail[i]] = p
        push!(occupied, avail[i])
    end
    
    return build_sfen(placement)
end

"""
Validate a puzzle SFEN is playable.
Uses the engine's existing functions for validation.
Wrapped in try-catch to handle invalid positions that would crash the engine.
"""
function is_valid_puzzle(sfen::String)::Bool
    try
        # Try to parse the position - this may fail for invalid positions
        state = parse_sfen(sfen)
        state === nothing && return false
        
        # Check that position isn't immediately over
        state.result != ONGOING && return false
        
        # Check branching factor (number of legal moves)
        moves = generate_legal_moves(state.board, state.side_to_move)
        length(moves) < 8 && return false
        
        # Check material balance
        abs(puzzle_material_balance(sfen)) > 5 && return false
        
        # Check that neither side has an immediate checkmate (unless many options)
        if length(moves) < 15
            for m in moves
                new_state = make_move(state, m)
                new_state.result != ONGOING && return false
            end
        end
        
        return true
    catch e
        # Position is invalid (e.g., king can be captured)
        return false
    end
end

"""
Generate a single valid puzzle.
"""
function generate_one_puzzle(seed::UInt64, config_idx::Int)::Tuple{String, UInt32}
    black_pieces, white_pieces = PUZZLE_PIECE_CONFIGS[config_idx]
    
    for attempt in 1:2000  # Increased attempts since many positions are invalid
        rng = MersenneTwister(seed + UInt64(attempt))
        sfen = generate_puzzle_sfen(rng, black_pieces, white_pieces)
        if sfen !== nothing && is_valid_puzzle(sfen)
            return (sfen, sfen_to_bitboard(sfen))
        end
    end
    
    # Fallback to standard position
    standard = "rbsgk/4p/5/P4/KGSBR b - 1"
    return (standard, sfen_to_bitboard(standard))
end

"""
Generate N puzzles and save to JSON file.
"""
function generate_puzzle_file(n::Int=365, output_path::String="frontend/public/puzzles.json")
    println("Generating $n puzzles...")
    
    puzzles = Vector{Dict{String, Any}}()
    
    for day in 1:n
        seed = UInt64(20241203 * 10000 + day)  # Base seed + day
        config_idx = ((day - 1) % length(PUZZLE_PIECE_CONFIGS)) + 1
        
        sfen, bitboard = generate_one_puzzle(seed, config_idx)
        
        push!(puzzles, Dict(
            "day" => day,
            "sfen" => sfen,
            "bitboard" => bitboard
        ))
        
        if day % 50 == 0
            println("  Generated $day / $n puzzles")
        end
    end
    
    # Write to JSON file
    open(output_path, "w") do f
        JSON3.pretty(f, puzzles)
    end
    
    println("Saved to $output_path")
    return puzzles
end

"""
Quick test - generate and print a few puzzles.
"""
function test_generator(n::Int=5)
    println("Testing puzzle generator...")
    for day in 1:n
        seed = UInt64(20241203 * 10000 + day)
        config_idx = ((day - 1) % length(PUZZLE_PIECE_CONFIGS)) + 1
        sfen, bb = generate_one_puzzle(seed, config_idx)
        println("Day $day: $sfen (bitboard: $bb)")
    end
end
