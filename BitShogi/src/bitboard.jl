# ===========================================================================
# bitboard.jl - Bitboard operations and utilities
# ===========================================================================

# A bitboard is an unsigned integer where each bit represents one square.
# Bit N is set (1) if "something is true" for square N+1.

# For minishogi (25 squares), we use UInt32:
#   Bit 0  → Square 1
#   Bit 1  → Square 2
#   ...
#   Bit 24 → Square 25
#   Bits 25-31 → unused (always 0)
# ===========================================================================

# return square bitboard
const SQUARE_BB = Tuple(Bitboard(1) << (sq - 1) for sq in 1: NUM_SQUARES)

# set a bit as occupied
@inline set_bit(bb::Bitboard, sq::Int)::Bitboard = bb | SQUARE_BB[sq]

# set a bit/square as empty
@inline clear_bit(bb::Bitboard, sq::Int)::Bitboard = bb & ~SQUARE_BB[sq]

# is this square/bit occupied
@inline test_bit(bb::Bitboard, sq::Int)::Bool = (bb & SQUARE_BB[sq]) != 0

# toggle a bit from current state, 0->1 or 1->0
@inline toggle_bit(bb::Bitboard, sq::Int)::Bitboard = bb ⊻ SQUARE_BB

# how many pieces
@inline popcount(bb::Bitboard)::Int = count_ones(bb)

# index of first piece(least sig piece) lsb(0b10100) → 3 
@inline function lsb(bb::Bitboard)::Int
    bb == 0 && return 0
    return trailing_zeros(bb) + 1
end

# index of last piece, most sig piece
@inline function msb(bb::Bitboard)::Int
    bb == 0 && return 0
    return (8 * sizeof(Bitboard) - 1) - leading_zeros(bb) + 1
end

# pop least sig bit
@inline function pop_lsb(bb::Bitboard)::Tuple{Int, Bitboard}
    sq = lsb(bb)
    # bb & (bb - 1) clears lowest set bit
    return (sq, bb & (bb - 1))
end

struct BitboardIterator
    bb::Bitboard
end

function Base.iterate(iter::BitboardIterator)
    iter.bb == 0 && return nothing
    sq, remaining = pop_lsb(iter.bb)
    return (sq, remaining)
end

function Base.iterate(iter::BitboardIterator, state::Bitboard)
    state == 0 && return nothing
    sq, remaining = pop_lsb(state)
    return (sq, remaining)
end

Base.eltype(::Type{BitboardIterator}) = Int
Base.IteratorSize(::Type{BitboardIterator}) = Base.SizeUnknown()

squares(bb::Bitboard) = BitboardIterator(bb)

# Example usage:
#   for sq in squares(white_pawns)
#       println("White pawn on square $sq")
#   end

function generate_rank_mask(r::Int)::Bitboard
    mask = EMPTY_BB
    for file in 1:BOARD_SIZE
        sq = square_index(r, file)
        mask = set_bit(mask, sq)
    end
    return mask
end 

# used to check for nifu(two pawns file)
function generate_file_mask(f::Int)::Bitboard
    mask = EMPTY_BB
    for rank in 1:BOARD_SIZE
        sq = square_index(rank, f)
        mask = set_bit(mask, sq)
    end
    return mask
end

# RANK_BB[1] = rank 1 (squares 1-5)
# FILE_BB[1] = file 1 (squares 1,6,11,16,21)
const RANK_BB = Tuple(generate_rank_mask(r) for r in 1:BOARD_SIZE)
const FILE_BB = Tuple(generate_file_mask(f) for f in 1:BOARD_SIZE)

# These are all squares where a piece CAN promote (not must promote)
const BLACK_PROMOTION_BB = reduce(|, RANK_BB[r] for r in BLACK_PROMOTION_RANKS)
const WHITE_PROMOTION_BB = reduce(|, RANK_BB[r] for r in WHITE_PROMOTION_RANKS)
# Must-promote masks (where pawns MUST promote - can't stay unpromoted)
const BLACK_MUST_PROMOTE_PAWN_BB = RANK_BB[BLACK_MUST_PROMOTE_RANK]
const WHITE_MUST_PROMOTE_PAWN_BB = RANK_BB[WHITE_MUST_PROMOTE_RANK]

# prevent wrapping around the board in the number
const NOT_FILE_1 = ~FILE_BB[1] & FULL_BB
const NOT_FILE_N = ~FILE_BB[BOARD_SIZE] & FULL_BB

@inline function shift_north(bb::Bitboard)::Bitboard
    return (bb >> BOARD_SIZE) & FULL_BB
end
@inline function shift_south(bb::Bitboard)::Bitboard
    return (bb << BOARD_SIZE) & FULL_BB
end
@inline function shift_west(bb::Bitboard)::Bitboard 
    return ((bb & NOT_FILE_1) >> 1) & FULL_BB
end
@inline function shift_east(bb::Bitboard)::Bitboard 
    return ((bb & NOT_FILE_N) << 1) & FULL_BB
end

# diagonal shifts 
@inline shift_north_east(bb::Bitboard)::Bitboard = shift_north(shift_east(bb))
@inline shift_north_west(bb::Bitboard)::Bitboard = shift_north(shift_west(bb))
@inline shift_south_east(bb::Bitboard)::Bitboard = shift_south(shift_east(bb))
@inline shift_south_west(bb::Bitboard)::Bitboard = shift_south(shift_west(bb))

### Helper functions

# is bits set
@inline is_empty(bb::Bitboard)::Bool = bb == EMPTY_BB
# @inline is_nonempty(bb:::Bitboard)::Bool = bb != EMPTY_BB

# one piece
@inline is_single(bb::Bitboard)::Bool = bb != 0 && (bb & (bb - 1)) == 0
# multiple pieces
@inline is_multiple(bb::Bitboard)::Bool = (bb & (bb - 1)) != 0

# and bitboards
@inline bb_and(a::Bitboard, b::Bitboard)::Bitboard = a & b
# or bitboards
@inline bb_or(a::Bitboard, b::Bitboard)::Bitboard = a | b
# pieces in a but not in b 
@inline bb_subtract(a::Bitboard, b::Bitboard)::Bitbaord = a & ~b
#invert
@inline bb_not(bb::Bitboard)::Bitboard = ~bb & FULL_BB

# check same rank
@inline same_rank(sq1::Int, sq2::Int)::Bool = rank_of(sq1) == rank_of(sq2)
# check same file
@inline same_file(sq1::Int, sq2::Int)::Bool = file_of(sq1) == file_of(sq2)

# return square bb
@inline square_bb(sq::Int)::Bitboard = SQUARE_BB[sq]

# rank mask of square
@inline rank_bb(sq::Int)::Bitboard = RANK_BB[rank_of(sq)]
# file mask of square
@inline file_bb(sq::Int)::Bitboard = FILE_BB[file_of(sq)]

# printing a bitboard 
function print_bitboard(bb::Bitboard, title::String = "Default")
    if !isempty(title)
        println(title)
    end

    print("    ")
    for f in 1:BOARD_SIZE
        print(" $f  ")
    end
    println()

    println("   +" * repeat("---+", BOARD_SIZE))
    for r in 1:BOARD_SIZE
        print(" $r |")
        for f in 1:BOARD_SIZE
            sq = square_index(r, f)
            if test_bit(bb, sq)
                print(" ◍ |") # \circlevertfill ◍
            else
                print("   |")
            end
        end
        println()
        println("   +" * repeat("---+", BOARD_SIZE))
    end
    println()
end

function print_bitboards(bbs::Vector{Tuple{String, Bitboard}})
    n = length(bbs)

    for (title, _) in bbs
        print(rpad(title, BOARD_SIZE * 4 + 6))
    end
    println()
    for r in 1:BOARD_SIZE
        # each bitboard row
        for (_, bb) in bbs
            print(" $r |")
            for f in 1:BOARD_SIZE
                sq = square_index(r, f)
                print(test_bit(bb, sq) ? " ◍ |" : "   |")
            end
            print("  ")
        end
        println()
        for i in 1:n
            print("   +" * repeat("---+", BOARD_SIZE))# * "     +" * repeat("---+", BOARD_SIZE))
            print("  ")
        end
        println()
    end
    println()
end

function bitboard_from_squares(squares::Int...)::Bitboard
    bb = EMPTY_BB
    for sq in squares
        bb = set_bit(bb, sq)
    end
    return bb
end

function bitboard_from_coords(coords::Tuple{Int, Int}...)::Bitboard
    bb = EMPTY_BB
    for (r,f) in coords
        sq = square_index(r, f)
        bb = set_bit(bb, sq)
    end
    return bb
end

# bb1 = bitboard_from_squares(1, 7, 13, 19, 25)
# print_bitboard(bb1, "Diagonal")

# popcount(bb1)
# lsb(bb1)
# for sq in squares(bb1)
#     println("Square: $sq, rank: $(rank_of(sq)), file: $(file_of(sq))")
# end

# shifted_bb1 = shift_south(bb1)
# print_bitboard(shifted_bb1)

# check nifu (two pawns same file)

# black_pawns = bitboard_from_squares(3, 13)
# print_bitboard(black_pawns)
# has_pawn_on_file_3 = (black_pawns & FILE_BB[3]) != 0
# pawn_count_on_file_3 = popcount(black_pawns & FILE_BB[3]) # 2 pawns on same file !

# print_bitboards([("bb1",bb1), ("shifted_south_bb1",shifted_bb1), ("bb1",bb1), ("shifted_south_bb1",shifted_bb1)])