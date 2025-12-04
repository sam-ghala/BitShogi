# board_generator.jl - Generate and save daily puzzles to JSON
# 
# Usage: 
#   include("board_generator.jl")
#   generate_puzzle_file(365, "frontend/public/puzzles.json")
#
# This creates puzzles.json in the frontend/public folder
#
# Pieces available (depends on engine support):
#   P/p = Pawn, L/l = Lance, N/n = Knight, S/s = Silver, G/g = Gold
#   B/b = Bishop, R/r = Rook, K/k = King
#
# Note: If certain piece types fail to generate, the engine may not support them yet.

using Random
using JSON3

# Standard minishogi position - will be filtered out
const STANDARD_SFEN = "rbsgk/4p/5/P4/KGSBR b - 1"

# Piece configurations (black_pieces, white_pieces) - SFEN characters
# Configs are tagged with which non-minishogi pieces they use for diagnostics
const PUZZLE_PIECE_CONFIGS = [
    # === Classic minishogi configs (no L/N) ===
    (["G", "S", "B", "R", "P"], ["g", "s", "b", "r", "p"], "minishogi"),
    (["G", "S", "R", "P", "P"], ["g", "s", "r", "p", "p"], "minishogi"),
    (["G", "S", "B", "P", "P"], ["g", "s", "b", "p", "p"], "minishogi"),
    (["R", "B"], ["r", "b"], "minishogi"),
    (["G", "G", "P", "P"], ["s", "s", "p", "p"], "minishogi"),
    (["G", "S"], ["g", "s"], "minishogi"),
    (["R", "G", "P"], ["r", "g", "p"], "minishogi"),
    (["B", "S", "P"], ["b", "s", "p"], "minishogi"),
    (["R", "G", "P"], ["b", "s", "p", "p"], "minishogi"),
    (["G", "P", "P", "P"], ["g", "p", "p", "p"], "minishogi"),
    (["G", "G", "S", "P"], ["g", "g", "s", "p"], "minishogi"),
    (["R", "B", "G"], ["r", "b", "g"], "minishogi"),
    (["R", "R"], ["g", "s", "p", "p", "p"], "minishogi"),
    (["S", "S", "P", "P"], ["s", "s", "p", "p"], "minishogi"),
    (["G", "S", "B", "R"], ["g", "s", "b", "r"], "minishogi"),
    
    # === Configs with Lance ===
    (["L", "L", "G", "P"], ["l", "l", "g", "p"], "lance"),
    (["R", "L", "G", "P"], ["r", "l", "g", "p"], "lance"),
    (["L", "L", "L", "G"], ["l", "l", "s", "p"], "lance"),
    (["L", "L", "S", "P"], ["b", "g", "p", "p"], "lance"),
    (["G", "S", "B", "L", "P"], ["g", "s", "b", "l", "p"], "lance"),
    
    # === Configs with Knight ===
    (["N", "N", "G", "P"], ["n", "n", "g", "p"], "knight"),
    (["N", "B", "G", "P"], ["n", "b", "g", "p"], "knight"),
    (["N", "N", "S", "S"], ["n", "n", "s", "s"], "knight"),
    (["N", "N", "G", "P", "P"], ["r", "g", "p"], "knight"),
    (["G", "S", "B", "N", "P"], ["g", "s", "b", "n", "p"], "knight"),
    
    # === Mixed Lance and Knight ===
    (["L", "N", "G", "P"], ["l", "n", "g", "p"], "lance+knight"),
    (["L", "N", "S", "G", "B"], ["l", "n", "s", "g", "b"], "lance+knight"),
    (["L", "L", "N", "N"], ["l", "l", "n", "n"], "lance+knight"),
    (["R", "L", "N", "G"], ["r", "l", "n", "g"], "lance+knight"),
    (["L", "N", "S", "G", "R"], ["l", "n", "s", "g", "r"], "lance+knight"),
]

const PUZZLE_PIECE_VALUES = Dict(
    "P" => 1, "p" => 1, 
    "L" => 3, "l" => 3,   # Lance - forward only but long range
    "N" => 3, "n" => 3,   # Knight - jumping piece
    "S" => 5, "s" => 5,
    "G" => 5, "g" => 5, 
    "B" => 8, "b" => 8,
    "R" => 9, "r" => 9, 
    "K" => 0, "k" => 0
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
        # Position is invalid (e.g., king can be captured, unsupported piece type)
        return false
    end
end

"""
Generate a single valid puzzle. Returns (sfen, bitboard, success).
"""
function generate_one_puzzle(seed::UInt64, config_idx::Int)::Tuple{String, UInt32, Bool}
    black_pieces, white_pieces, _ = PUZZLE_PIECE_CONFIGS[config_idx]
    
    for attempt in 1:2000
        rng = MersenneTwister(seed + UInt64(attempt))
        sfen = generate_puzzle_sfen(rng, black_pieces, white_pieces)
        if sfen !== nothing && is_valid_puzzle(sfen)
            return (sfen, sfen_to_bitboard(sfen), true)
        end
    end
    
    # Failed to generate valid puzzle for this config
    return ("", UInt32(0), false)
end

"""
Generate N puzzles and save to JSON file.
Filters out the standard minishogi position and failed configs.
"""
function generate_puzzle_file(n::Int=365, output_path::String="frontend/public/puzzles.json")
    println("Generating $n puzzles...")
    println("Using $(length(PUZZLE_PIECE_CONFIGS)) piece configurations")
    
    puzzles = Vector{Dict{String, Any}}()
    config_success = Dict{String, Int}()
    config_fail = Dict{String, Int}()
    
    day = 1
    attempts = 0
    max_attempts = n * 3  # Allow extra attempts to hit target count
    
    while length(puzzles) < n && attempts < max_attempts
        attempts += 1
        seed = UInt64(20241203 * 10000 + attempts)
        config_idx = ((attempts - 1) % length(PUZZLE_PIECE_CONFIGS)) + 1
        _, _, tag = PUZZLE_PIECE_CONFIGS[config_idx]
        
        sfen, bitboard, success = generate_one_puzzle(seed, config_idx)
        
        if !success
            config_fail[tag] = get(config_fail, tag, 0) + 1
            continue
        end
        
        # Filter out standard position
        if sfen == STANDARD_SFEN
            continue
        end
        
        config_success[tag] = get(config_success, tag, 0) + 1
        
        push!(puzzles, Dict(
            "day" => length(puzzles) + 1,
            "sfen" => sfen,
            "bitboard" => bitboard
        ))
        
        if length(puzzles) % 50 == 0
            println("  Generated $(length(puzzles)) / $n puzzles")
        end
    end
    
    # Print diagnostics
    println("\n=== Config Success Rates ===")
    for tag in sort(collect(keys(config_success)))
        s = get(config_success, tag, 0)
        f = get(config_fail, tag, 0)
        total = s + f
        pct = total > 0 ? round(100 * s / total, digits=1) : 0
        println("  $tag: $s/$total ($pct%)")
    end
    
    # Check for configs that never succeeded
    for tag in sort(collect(keys(config_fail)))
        if !haskey(config_success, tag)
            println("  ⚠️  $tag: 0 successes - engine may not support these pieces!")
        end
    end
    
    if length(puzzles) < n
        println("\n⚠️  Only generated $(length(puzzles)) puzzles (target: $n)")
        println("   Some piece configurations may not be supported by the engine.")
    end
    
    # Write to JSON file
    open(output_path, "w") do f
        JSON3.pretty(f, puzzles)
    end
    
    println("\nSaved $(length(puzzles)) puzzles to $output_path")
    return puzzles
end

"""
Quick test - generate and print a few puzzles.
"""
function test_generator(n::Int=5)
    println("Testing puzzle generator...")
    for i in 1:n
        seed = UInt64(20241203 * 10000 + i)
        config_idx = ((i - 1) % length(PUZZLE_PIECE_CONFIGS)) + 1
        black, white, tag = PUZZLE_PIECE_CONFIGS[config_idx]
        sfen, bb, success = generate_one_puzzle(seed, config_idx)
        if success
            println("Config $config_idx ($tag): $sfen (bitboard: $bb)")
        else
            println("Config $config_idx ($tag): FAILED - engine may not support pieces: $black / $white")
        end
    end
end

"""
Test which piece types are supported by the engine.
"""
function test_piece_support()
    println("Testing piece type support...")
    
    # Test positions where pieces are placed safely (kings far apart, no immediate captures)
    test_positions = [
        ("Pawn",   "4k/5/5/2P2/K4 b - 1"),
        ("Silver", "4k/5/5/2S2/K4 b - 1"),
        ("Gold",   "4k/5/5/2G2/K4 b - 1"),
        ("Bishop", "4k/5/5/2B2/K4 b - 1"),
        ("Rook",   "4k/5/5/2R2/K4 b - 1"),
        ("Lance",  "4k/5/5/2L2/K4 b - 1"),
        ("Knight", "4k/5/2N2/5/K4 b - 1"),  # Knight needs room to jump
    ]
    
    for (name, sfen) in test_positions
        try
            state = parse_sfen(sfen)
            if state === nothing
                println("  $name: ❌ parse_sfen returned nothing")
                continue
            end
            moves = generate_legal_moves(state.board, state.side_to_move)
            println("  $name: ✓ $(length(moves)) legal moves")
        catch e
            println("  $name: ❌ Error: $(typeof(e))")
            # Print more detail for debugging
            if e isa MethodError
                println("         Method: $(e.f), Args: $(typeof.(e.args))")
            else
                println("         $e")
            end
        end
    end
end
# test_piece_support()
generate_puzzle_file(1000)