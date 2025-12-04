# board_generator.jl - Generate symmetric mirrored puzzles
# 
# Usage: 
#   include("board_generator.jl")
#   generate_puzzle_file(365, "frontend/public/puzzles.json")
#
# Design:
#   - 16 king positions (perimeter squares), each creates a board template
#   - All pieces are mirrored: Black piece at sq → White piece at (26-sq)
#   - Random piece count (2-5 additional pieces per side, so 3-6 total with king)
#   - Full piece set: Pawn, Lance, Knight, Silver, Gold, Bishop, Rook
#   - Placement constraints enforced (pawns/lances not on back rank, knights not on back two ranks)
#   - Nifu rule enforced (no two pawns on same file per side)

using Random
using JSON3

# All piece types (excluding king which is placed separately)
const PIECE_TYPES = ["P", "L", "N", "S", "G", "B", "R"]

# Piece values for reference
const PUZZLE_PIECE_VALUES = Dict(
    "P" => 1, "p" => 1, 
    "L" => 3, "l" => 3,
    "N" => 3, "n" => 3,
    "S" => 5, "s" => 5,
    "G" => 5, "g" => 5, 
    "B" => 8, "b" => 8,
    "R" => 9, "r" => 9, 
    "K" => 0, "k" => 0
)

# 16 perimeter squares (the outer ring of the 5x5 board)
# Board layout:
#  1  2  3  4  5   (rank 1)
#  6  7  8  9 10   (rank 2)
# 11 12 13 14 15   (rank 3)
# 16 17 18 19 20   (rank 4)
# 21 22 23 24 25   (rank 5)
const PERIMETER_SQUARES = [1, 2, 3, 4, 5, 6, 10, 11, 15, 16, 20, 21, 22, 23, 24, 25]

"""
Mirror a square through the center of the board.
Point reflection: sq + mirror = 26
"""
mirror_square(sq::Int)::Int = 26 - sq

"""
Get the rank (1-5) of a square.
"""
get_rank(sq::Int)::Int = (sq - 1) ÷ 5 + 1

"""
Get the file (1-5) of a square.
"""
get_file(sq::Int)::Int = (sq - 1) % 5 + 1

"""
Check if a piece type can be placed on a square (for Black).
Returns false if the piece would have no legal moves.

Constraints:
- Pawns/Lances: can't be on rank 1 (Black's back rank, no forward moves)
- Knights: can't be on ranks 1-2 (need room to jump forward)
"""
function can_place_piece(piece::String, sq::Int)::Bool
    rank = get_rank(sq)
    
    if piece == "P" || piece == "L"
        # Pawns and Lances can't be on rank 1 (back rank for Black)
        return rank != 1
    elseif piece == "N"
        # Knights can't be on ranks 1-2 (need room to jump forward)
        return rank > 2
    end
    
    # All other pieces (S, G, B, R) can go anywhere
    return true
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
Generate a symmetric puzzle for a given king position index (1-16).
Returns the SFEN string or nothing if generation fails.
"""
function generate_symmetric_puzzle(rng::AbstractRNG, king_idx::Int)::Union{String, Nothing}
    placement = Dict{Int, String}()
    occupied = Set{Int}()
    
    # Place kings based on the perimeter index
    black_king_sq = PERIMETER_SQUARES[king_idx]
    white_king_sq = mirror_square(black_king_sq)
    
    placement[black_king_sq] = "K"
    placement[white_king_sq] = "k"
    push!(occupied, black_king_sq)
    push!(occupied, white_king_sq)
    
    # Random number of additional pieces per side: 2-5 (so 3-6 total with king)
    num_pieces = rand(rng, 2:5)
    
    # Track which files have Black pawns (for nifu rule)
    pawn_files = Set{Int}()
    
    # Generate random pieces
    for _ in 1:num_pieces
        # Pick a random piece type
        piece = PIECE_TYPES[rand(rng, 1:length(PIECE_TYPES))]
        
        # Find valid squares for this piece
        valid_squares = Int[]
        for sq in 1:25
            # Skip center square (can't mirror to itself)
            sq == 13 && continue
            
            # Skip if occupied
            sq in occupied && continue
            
            # Skip if mirrored square is occupied
            mirror_square(sq) in occupied && continue
            
            # Check placement constraints for this piece type
            !can_place_piece(piece, sq) && continue
            
            # Check nifu rule for pawns (no two pawns on same file)
            if piece == "P"
                file = get_file(sq)
                file in pawn_files && continue
            end
            
            push!(valid_squares, sq)
        end
        
        # If no valid squares, skip this piece
        isempty(valid_squares) && continue
        
        # Pick a random valid square
        sq = valid_squares[rand(rng, 1:length(valid_squares))]
        mirror_sq = mirror_square(sq)
        
        # Place Black piece and White piece (mirrored, lowercase)
        placement[sq] = piece
        placement[mirror_sq] = lowercase(piece)
        push!(occupied, sq)
        push!(occupied, mirror_sq)
        
        # Track pawn files for nifu
        if piece == "P"
            push!(pawn_files, get_file(sq))
        end
    end
    
    return build_sfen(placement)
end

"""
Validate a puzzle SFEN is playable.
"""
function is_valid_puzzle(sfen::String)::Bool
    try
        state = parse_sfen(sfen)
        state === nothing && return false
        
        # Check that position isn't immediately over
        state.result != ONGOING && return false
        
        # Check branching factor (number of legal moves) - at least 8 moves
        moves = generate_legal_moves(state.board, state.side_to_move)
        length(moves) < 8 && return false
        
        return true
    catch e
        return false
    end
end

"""
Generate a single valid puzzle for a given king position.
Returns (sfen, bitboard, success).
"""
function generate_one_puzzle(seed::UInt64, king_idx::Int)::Tuple{String, UInt32, Bool}
    for attempt in 1:2000
        rng = MersenneTwister(seed + UInt64(attempt))
        sfen = generate_symmetric_puzzle(rng, king_idx)
        if sfen !== nothing && is_valid_puzzle(sfen)
            return (sfen, sfen_to_bitboard(sfen), true)
        end
    end
    return ("", UInt32(0), false)
end

"""
Generate N puzzles and save to JSON file.
Cycles through all 16 king positions.
"""
function generate_puzzle_file(n::Int=365, output_path::String="frontend/public/puzzles.json")
    println("Generating $n symmetric puzzles...")
    println("Using 16 king position templates (perimeter squares)")
    
    puzzles = Vector{Dict{String, Any}}()
    king_position_counts = zeros(Int, 16)
    failed_counts = zeros(Int, 16)
    
    attempts = 0
    max_attempts = n * 3
    
    while length(puzzles) < n && attempts < max_attempts
        attempts += 1
        seed = UInt64(20241204 * 10000 + attempts)
        king_idx = ((attempts - 1) % 16) + 1
        
        sfen, bitboard, success = generate_one_puzzle(seed, king_idx)
        
        if !success
            failed_counts[king_idx] += 1
            continue
        end
        
        king_position_counts[king_idx] += 1
        
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
    println("\n=== King Position Distribution ===")
    for (idx, count) in enumerate(king_position_counts)
        sq = PERIMETER_SQUARES[idx]
        file, rank = get_file(sq), get_rank(sq)
        failed = failed_counts[idx]
        total = count + failed
        pct = total > 0 ? round(100 * count / total, digits=1) : 0
        println("  Position $idx (file=$file, rank=$rank): $count puzzles ($pct% success)")
    end
    
    if length(puzzles) < n
        println("\n⚠️  Only generated $(length(puzzles)) puzzles (target: $n)")
    end
    
    # Shuffle puzzles so king positions are mixed throughout the year
    shuffle!(puzzles)
    
    # Re-number days after shuffle
    for (i, puzzle) in enumerate(puzzles)
        puzzle["day"] = i
    end
    
    # Write to JSON file
    open(output_path, "w") do f
        JSON3.pretty(f, puzzles)
    end
    
    println("\nSaved $(length(puzzles)) puzzles to $output_path")
    return puzzles
end

"""
Quick test - generate and print a few puzzles for each king position.
"""
function test_generator(n::Int=16)
    println("Testing symmetric puzzle generator...")
    println("King positions are on the perimeter, mirrored through center.\n")
    
    for i in 1:min(n, 16)
        seed = UInt64(20241204 * 10000 + i * 1000)
        sfen, bb, success = generate_one_puzzle(seed, i)
        sq = PERIMETER_SQUARES[i]
        mirror_sq = mirror_square(sq)
        file, rank = get_file(sq), get_rank(sq)
        m_file, m_rank = get_file(mirror_sq), get_rank(mirror_sq)
        
        if success
            println("King $i: Black ($file,$rank) vs White ($m_file,$m_rank)")
            println("  SFEN: $sfen")
            println("  Bitboard: $bb\n")
        else
            println("King $i: Black ($file,$rank) vs White ($m_file,$m_rank) - FAILED\n")
        end
    end
end

"""
Visual test - print a board from SFEN.
"""
function print_board(sfen::String)
    board_part = split(sfen, " ")[1]
    ranks = split(board_part, "/")
    
    println("  1 2 3 4 5")
    println("  ---------")
    for (i, rank_str) in enumerate(ranks)
        print(Char('a' + i - 1), "|")
        for c in rank_str
            if isdigit(c)
                print(". " ^ parse(Int, c))
            elseif c == '+'
                # Skip promotion marker, handled with next char
            else
                print(c, " ")
            end
        end
        println()
    end
    println()
end