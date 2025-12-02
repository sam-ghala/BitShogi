# attack_tables.jl

# for each piece type and square, compute a bitboard showing where given piece can attack from given square

# King on square 13 (center of 5x5 board)

#          1   2   3   4   5
#        +---+---+---+---+---+
#     1  |   |   |   |   |   |
#        +---+---+---+---+---+
#     2  |   | ● | ● | ● |   |
#        +---+---+---+---+---+
#     3  |   | ● | K | ● |   |
#        +---+---+---+---+---+
#     4  |   | ● | ● | ● |   |
#        +---+---+---+---+---+
#     5  |   |   |   |   |   |
#        +---+---+---+---+---+

# KING_ATTACKS[13] = bitboard with squares 7,8,9,12,14,17,18,19 set

# \circlevertfill ◍


# attack tables for pieces that move one square
function compute_step_attacks(sq::Int, directions::Tuple)::Bitboard
    attacks = EMPTY_BB
    sq_rank = rank_of(sq)
    sq_file = file_of(sq)

    for dir in directions
        to_sq = sq + dir

        if !is_valid_square(to_sq)
            continue
        end
        to_rank = rank_of(to_sq)
        to_file = file_of(to_sq)
        # check if we went off the board
        if abs(to_rank - sq_rank) <= 1 && abs(to_file - sq_file) <= 1
            attacks = set_bit(attacks, to_sq)
        end
    end
    return attacks
end

# king attacks 
function generate_king_attacks()::NTuple{NUM_SQUARES, Bitboard}
    attacks = Vector{Bitboard}(undef, NUM_SQUARES)
    
    for sq in 1:NUM_SQUARES
        attacks[sq] = compute_step_attacks(sq, ALL_DIRS)
    end
    return Tuple(attacks)
end

const KING_ATTACKS = generate_king_attacks()

# gold attacks 
const GOLD_DIRS_BLACK = (NORTH, NORTH_EAST, EAST, SOUTH, WEST, NORTH_WEST)
const GOLD_DIRS_WHITE = (SOUTH, SOUTH_WEST, WEST, NORTH, SOUTH_EAST, EAST)

function generate_gold_attacks()::NTuple{2, NTuple{NUM_SQUARES, Bitboard}}
    black_attacks = Vector{Bitboard}(undef, NUM_SQUARES)
    white_attacks = Vector{Bitboard}(undef, NUM_SQUARES)

    for sq in 1:NUM_SQUARES
        black_attacks[sq] = compute_step_attacks(sq, GOLD_DIRS_BLACK)
        white_attacks[sq] = compute_step_attacks(sq, GOLD_DIRS_WHITE)
    end
    return (Tuple(black_attacks), Tuple(white_attacks))
end

const GOLD_ATTACKS = generate_gold_attacks()
@inline gold_attacks(sq::Int, color::Color)::Bitboard = GOLD_ATTACKS[Int(color)][sq]

# silver attacks
const SILVER_DIRS_BLACK = (NORTH, NORTH_EAST, NORTH_WEST, SOUTH_EAST, SOUTH_WEST)
const SILVER_DIRS_WHITE = (SOUTH, SOUTH_EAST, SOUTH_WEST, NORTH_EAST, NORTH_WEST)

function generate_silver_attacks()::NTuple{2, NTuple{NUM_SQUARES, Bitboard}}
    black_attacks = Vector{Bitboard}(undef, NUM_SQUARES)
    white_attacks = Vector{Bitboard}(undef, NUM_SQUARES)
    
    for sq in 1:NUM_SQUARES
        black_attacks[sq] = compute_step_attacks(sq, SILVER_DIRS_BLACK)
        white_attacks[sq] = compute_step_attacks(sq, SILVER_DIRS_WHITE)
    end
    return (Tuple(black_attacks), Tuple(white_attacks))
end

const SILVER_ATTACKS = generate_silver_attacks()
@inline silver_attacks(sq::Int, color::Color)::Bitboard = SILVER_ATTACKS[Int(color)][sq]

# knight attacks
const KNIGHT_JUMP_BLACK_NE = NORTH + NORTH + EAST
const KNIGHT_JUMP_BLACK_NW = NORTH + NORTH + WEST
const KNIGHT_JUMP_WHITE_SE = SOUTH + SOUTH + EAST
const KNIGHT_JUMP_WHITE_SW = SOUTH + SOUTH + WEST

function compute_knight_attacks(sq::Int, color::Color)::Bitboard
    attacks = EMPTY_BB
    sq_rank = rank_of(sq)
    sq_file = file_of(sq)

    if color == BLACK
        jumps = (KNIGHT_JUMP_BLACK_NE, KNIGHT_JUMP_BLACK_NW)
        expected_rank_diff = -2
    else
        jumps = (KNIGHT_JUMP_WHITE_SE, KNIGHT_JUMP_WHITE_SW)
        expected_rank_diff = 2
    end
    for jump in jumps
        to_sq = sq + jump
        if !is_valid_square(to_sq)
            continue
        end

        to_rank = rank_of(to_sq)
        to_file = file_of(to_sq)
        rank_diff = to_rank - sq_rank
        file_diff = abs(to_file - sq_file)
        if rank_diff == expected_rank_diff && file_diff == 1
            attacks = set_bit(attacks, to_sq)
        end
    end
    return attacks
end

function generate_knight_attacks()::NTuple{2, NTuple{NUM_SQUARES, Bitboard}}
    black_attacks = Vector{Bitboard}(undef, NUM_SQUARES)
    white_attacks = Vector{Bitboard}(undef, NUM_SQUARES)
    
    for sq in 1:NUM_SQUARES
        black_attacks[sq] = compute_knight_attacks(sq, BLACK)
        white_attacks[sq] = compute_knight_attacks(sq, WHITE)
    end
    return (Tuple(black_attacks), Tuple(white_attacks))
end

const KNIGHT_ATTACKS = generate_knight_attacks()
@inline knight_attacks(sq::Int, color::Color)::Bitboard = KNIGHT_ATTACKS[Int(color)][sq]

# pawn attacks
function generate_pawn_attacks()::NTuple{2, NTuple{NUM_SQUARES, Bitboard}}
    black_attacks = Vector{Bitboard}(undef, NUM_SQUARES)
    white_attacks = Vector{Bitboard}(undef, NUM_SQUARES)
    
    for sq in 1:NUM_SQUARES
        black_to = sq + NORTH
        if is_valid_square(black_to) && rank_of(black_to) == rank_of(sq) - 1
            black_attacks[sq] = set_bit(EMPTY_BB, black_to)
        else
            black_attacks[sq] = EMPTY_BB
        end

        white_to = sq + SOUTH
        if is_valid_square(white_to) && rank_of(white_to) == rank_of(sq) + 1
            white_attacks[sq] = set_bit(EMPTY_BB, white_to)
        else
            white_attacks[sq] = EMPTY_BB
        end
    end
    return (Tuple(black_attacks), Tuple(white_attacks))
end

const PAWN_ATTACKS = generate_pawn_attacks()
@inline pawn_attacks(sq::Int, color::Color)::Bitboard = PAWN_ATTACKS[Int(color)][sq]

# promoted pieces 
function generate_orthogonal_steps()::NTuple{NUM_SQUARES, Bitboard}
    attacks = Vector{Bitboard}(undef, NUM_SQUARES)
    for sq in 1:NUM_SQUARES
        attacks[sq] = compute_step_attacks(sq, ORTHOGONAL_DIRS)
    end
    return Tuple(attacks)
end
function generate_diagonal_steps()::NTuple{NUM_SQUARES, Bitboard}
    attacks = Vector{Bitboard}(undef, NUM_SQUARES)
    for sq in 1:NUM_SQUARES
        attacks[sq] = compute_step_attacks(sq, DIAGONAL_DIRS)
    end
    return Tuple(attacks)
end

const HORSE_BONUS_ATTACKS = generate_orthogonal_steps()
const DRAGON_BONUS_ATTACKS = generate_diagonal_steps()

@inline horse_bonus_attacks(sq::Int)::Bitboard = HORSE_BONUS_ATTACKS[sq]
@inline dragon_bonus_attacks(sq::Int)::Bitboard = DRAGON_BONUS_ATTACKS[sq]

# non-sliding piece lookup table for attacks
function get_piece_attacks(sq::Int, pt::PieceType, color::Color)::Bitboard
    if pt == KING
        return KING_ATTACKS[sq]
    elseif pt == GOLD || moves_like_gold(pt)
        return gold_attacks(sq, color)
    elseif pt == SILVER
        return silver_attacks(sq, color)
    elseif pt == KNIGHT
        return knight_attacks(sq, color)
    elseif pt == PAWN
        return pawn_attacks(sq, color)
    elseif pt == PROMOTED_BISHOP
        return horse_bonus_attacks(sq)
    elseif pt == PROMOTED_ROOK
        return dragon_bonus_attacks(sq)
    else
        return EMPTY_BB
    end
end

function print_attack_table(attacks::NTuple{NUM_SQUARES, Bitboard}, piece_name::String)
    for sq in 1:NUM_SQUARES
        if attacks[sq] != EMPTY_BB
            print_bitboard(attacks[sq], "$piece_name on square $sq ($(rank_of(sq)),$(file_of(sq)))")
        end
    end
end

function print_color_attack_table(attacks::NTuple{2, NTuple{NUM_SQUARES, Bitboard}}, piece_name::String)
    for (color_idx, color_name) in [(1, "BLACK"), (2, "WHITE")]
        println("=== $piece_name ($color_name) Attack Table ===")
        println()
        
        for sq in 1:NUM_SQUARES
            if attacks[color_idx][sq] != EMPTY_BB
                print_bitboard(attacks[color_idx][sq], "$piece_name on square $sq ($(rank_of(sq)),$(file_of(sq)))")
            end
        end
    end
end

# print_attack_table(KING_ATTACKS, "King")
# print_color_attack_table(GOLD_ATTACKS, "Gold")
# print_attack_table(DRAGON_BONUS_ATTACKS, "Dragon")
# print_attack_table(HORSE_BONUS_ATTACKS, "Horse")

