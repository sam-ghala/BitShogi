# daily_puzzle.jl - Daily puzzle generation for BitShogi
# Generates a deterministic "random" position based on the current date
# Uses SFEN strings to avoid direct BoardState manipulation

using Random
using Dates

# Piece values for material balance
const DAILY_PIECE_VALUES = Dict(
    "P" => 1, "p" => 1,
    "S" => 5, "s" => 5,
    "G" => 5, "g" => 5,
    "B" => 8, "b" => 8,
    "R" => 9, "r" => 9,
    "K" => 0, "k" => 0
)

# Piece configurations to cycle through (excluding kings which are always present)
# Each config is: (black_pieces, white_pieces) where pieces are SFEN characters
const DAILY_PIECE_CONFIGS = [
    # Config 1: Full army
    (["G", "S", "B", "R", "P"], ["g", "s", "b", "r", "p"]),
    # Config 2: No bishops (infantry battle)
    (["G", "S", "R", "P", "P"], ["g", "s", "r", "p", "p"]),
    # Config 3: No rooks (diagonal focus)
    (["G", "S", "B", "P", "P"], ["g", "s", "b", "p", "p"]),
    # Config 4: Heavy pieces only
    (["R", "B"], ["r", "b"]),
    # Config 5: Gold vs Silver armies
    (["G", "G", "P", "P"], ["s", "s", "p", "p"]),
    # Config 6: Minimal - just generals
    (["G", "S"], ["g", "s"]),
    # Config 7: Rook battle
    (["R", "G", "P"], ["r", "g", "p"]),
    # Config 8: Bishop battle  
    (["B", "S", "P"], ["b", "s", "p"]),
    # Config 9: Asymmetric - Rook vs Bishop
    (["R", "G", "P"], ["b", "s", "p", "p"]),
    # Config 10: Pawn army
    (["G", "P", "P", "P"], ["g", "p", "p", "p"]),
    # Config 11: Double generals
    (["G", "G", "S", "P"], ["g", "g", "s", "p"]),
    # Config 12: Power pieces
    (["R", "B", "G"], ["r", "b", "g"]),
    # Config 13: Asymmetric - Heavy vs Light
    (["R", "R"], ["g", "s", "p", "p", "p"]),
    # Config 14: All silvers
    (["S", "S", "P", "P"], ["s", "s", "p", "p"]),
    # Config 15: Standard but no pawns
    (["G", "S", "B", "R"], ["g", "s", "b", "r"]),
]

"""
    get_date_seed(date::Date) -> UInt64

Convert a date to a deterministic seed value.
"""
function get_date_seed(date::Date)::UInt64
    y = year(date)
    m = month(date)
    d = day(date)
    seed = UInt64(y * 10000 + m * 100 + d)
    seed = seed ⊻ (seed << 13)
    seed = seed ⊻ (seed >> 7)
    seed = seed ⊻ (seed << 17)
    return seed
end

"""
    is_king_safe_square(sq::Int, other_king_sq::Int) -> Bool

Check if a square is safe for a king (not adjacent to other king).
Squares are 1-25 (1=top-left, 5=top-right, 25=bottom-right)
"""
function is_king_safe_square(sq::Int, other_king_sq::Int)::Bool
    if other_king_sq == -1
        return true
    end
    
    sq_file = (sq - 1) % 5 + 1
    sq_rank = (sq - 1) ÷ 5 + 1
    other_file = (other_king_sq - 1) % 5 + 1
    other_rank = (other_king_sq - 1) ÷ 5 + 1
    
    file_diff = abs(sq_file - other_file)
    rank_diff = abs(sq_rank - other_rank)
    
    return file_diff > 1 || rank_diff > 1
end

"""
    build_sfen_from_placement(placement::Dict{Int, String}) -> String

Build a SFEN board string from a placement dictionary.
placement maps square (1-25) to piece character (e.g., "K", "p", "R")
"""
function build_sfen_from_placement(placement::Dict{Int, String})::String
    ranks = String[]
    
    for rank in 1:5
        rank_str = ""
        empty_count = 0
        
        for file in 1:5
            sq = (rank - 1) * 5 + file
            
            if haskey(placement, sq)
                if empty_count > 0
                    rank_str *= string(empty_count)
                    empty_count = 0
                end
                rank_str *= placement[sq]
            else
                empty_count += 1
            end
        end
        
        if empty_count > 0
            rank_str *= string(empty_count)
        end
        
        push!(ranks, rank_str)
    end
    
    return join(ranks, "/")
end

"""
    generate_random_sfen(rng::AbstractRNG, black_pieces::Vector{String}, white_pieces::Vector{String}) -> Union{String, Nothing}

Generate a random SFEN string with the given piece configuration.
"""
function generate_random_sfen(rng::AbstractRNG, black_pieces::Vector{String}, white_pieces::Vector{String})::Union{String, Nothing}
    placement = Dict{Int, String}()
    occupied = Set{Int}()
    
    # Place black king (prefer ranks 3-5 for black)
    black_king_candidates = shuffle(rng, [sq for sq in 1:25 if (sq-1) ÷ 5 >= 2])
    black_king_sq = -1
    for sq in black_king_candidates
        black_king_sq = sq
        placement[sq] = "K"
        push!(occupied, sq)
        break
    end
    
    if black_king_sq == -1
        return nothing
    end
    
    # Place white king (prefer ranks 1-3, not adjacent to black king)
    white_king_candidates = shuffle(rng, [sq for sq in 1:25 if (sq-1) ÷ 5 <= 2])
    white_king_sq = -1
    for sq in white_king_candidates
        if is_king_safe_square(sq, black_king_sq) && !(sq in occupied)
            white_king_sq = sq
            placement[sq] = "k"
            push!(occupied, sq)
            break
        end
    end
    
    if white_king_sq == -1
        return nothing
    end
    
    # Place black pieces
    available = shuffle(rng, [sq for sq in 1:25 if !(sq in occupied)])
    for (i, piece) in enumerate(black_pieces)
        if i > length(available)
            return nothing
        end
        sq = available[i]
        placement[sq] = piece
        push!(occupied, sq)
    end
    
    # Refresh available squares for white
    available = shuffle(rng, [sq for sq in 1:25 if !(sq in occupied)])
    for (i, piece) in enumerate(white_pieces)
        if i > length(available)
            return nothing
        end
        sq = available[i]
        placement[sq] = piece
        push!(occupied, sq)
    end
    
    # Build SFEN: board side_to_move hand move_count
    board_sfen = build_sfen_from_placement(placement)
    return "$(board_sfen) b - 1"
end

"""
    calculate_material_from_sfen(sfen::String) -> Tuple{Int, Int}

Calculate material for black and white from a SFEN string.
Returns (black_material, white_material)
"""
function calculate_material_from_sfen(sfen::String)::Tuple{Int, Int}
    board_part = split(sfen, " ")[1]
    black_material = 0
    white_material = 0
    
    for char in board_part
        if char in ['/', '1', '2', '3', '4', '5', '+']
            continue
        end
        
        char_str = string(char)
        value = get(DAILY_PIECE_VALUES, char_str, 0)
        
        if isuppercase(char)
            black_material += value
        else
            white_material += value
        end
    end
    
    return (black_material, white_material)
end

"""
    calculate_occupied_bitboard(sfen::String) -> UInt32

Calculate the bitboard integer of occupied squares from SFEN.
"""
function calculate_occupied_bitboard(sfen::String)::UInt32
    board_part = split(sfen, " ")[1]
    ranks = split(board_part, "/")
    
    bitboard = UInt32(0)
    sq = 0
    
    for rank_str in ranks
        for char in rank_str
            if char == '+'
                continue
            elseif isdigit(char)
                sq += parse(Int, char)
            else
                # This is a piece
                bitboard |= UInt32(1) << sq
                sq += 1
            end
        end
    end
    
    return bitboard
end

"""
    is_valid_puzzle_sfen(sfen::String) -> Bool

Check if a SFEN represents a valid puzzle position.
Uses the engine's existing functions for validation.
"""
function is_valid_puzzle_sfen(sfen::String)::Bool
    # Try to parse the position
    state = parse_sfen(sfen)
    if state === nothing
        return false
    end
    
    # Check branching factor (number of legal moves)
    moves = generate_legal_moves(state)
    if length(moves) < 8
        return false  # Too few moves
    end
    
    # Check material balance
    black_mat, white_mat = calculate_material_from_sfen(sfen)
    if abs(black_mat - white_mat) > 5
        return false
    end
    
    # Check that position isn't immediately over
    if state.result != ONGOING
        return false
    end
    
    # Check that neither side has an immediate checkmate
    for move in moves
        new_state = make_move(state, move)
        if new_state.result != ONGOING
            # Only allow if there are many other options
            if length(moves) < 15
                return false
            end
        end
    end
    
    # Check white also has reasonable options
    white_state = parse_sfen(replace(sfen, " b " => " w "))
    if white_state !== nothing
        white_moves = generate_legal_moves(white_state)
        if length(white_moves) < 5
            return false
        end
    end
    
    return true
end

"""
    generate_daily_puzzle(date::Date) -> Tuple{String, UInt32}

Generate the daily puzzle for a given date.
Returns (sfen, bitboard_integer)
"""
function generate_daily_puzzle(date::Date)::Tuple{String, UInt32}
    base_seed = get_date_seed(date)
    
    # Select piece configuration based on day of year
    day_of_year_val = dayofyear(date)
    config_idx = ((day_of_year_val - 1) % length(DAILY_PIECE_CONFIGS)) + 1
    black_pieces, white_pieces = DAILY_PIECE_CONFIGS[config_idx]
    
    # Try to generate a valid position
    for attempt in 1:1000
        seed = base_seed + UInt64(attempt - 1)
        rng = MersenneTwister(seed)
        
        sfen = generate_random_sfen(rng, black_pieces, white_pieces)
        
        if sfen !== nothing && is_valid_puzzle_sfen(sfen)
            bitboard_int = calculate_occupied_bitboard(sfen)
            return (sfen, bitboard_int)
        end
    end
    
    # Fallback to standard starting position
    @warn "Failed to generate daily puzzle for $date, using standard position"
    standard_sfen = "rbsgk/4p/5/P4/KGSBR b - 1"
    return (standard_sfen, calculate_occupied_bitboard(standard_sfen))
end

"""
    generate_today_puzzle() -> Tuple{String, UInt32}

Generate the puzzle for today.
"""
function generate_today_puzzle()::Tuple{String, UInt32}
    return generate_daily_puzzle(today())
end
