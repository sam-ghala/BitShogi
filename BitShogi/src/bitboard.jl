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

include("types.jl")

# return square bitboard
const SQUARE_BB = Tuple(Bitboard(1) << (sq - 1) for sq in 1: NUM_SQUARES)

# set a bit as occupied
@inline set_bit(bb::Bitboard, sq::Int)::Bitboard = bb | SQUARE_BB[sq]

# set a bit/square as empty
@inline clear_bit(bb::Bitboard, sq::Int)::Bitboard = bb & ~SQUARE_BB[sq]

# is this square/bit occupied
@inline test_bit(bb::Bitboard, sq::Int)::Bool = (BB & SQUARE_BB[sq]) != 0

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
@inline function pop_lsb(bb::Bitboard)::Tuple{Int, Bitbaord}
    sq = lsb(bb)
    # bb & (bb - 1) clears lowest set bit
    return (sq, bb & (bb - 1))
end

struct BitboardIterator
    bb::Bitbaord
end

function Base.iterate(iter::BitboardIterator)
    iter.bb == 0 && return 0
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
const BLACK_MUST_PROMOTE_PAWN_BB = RANK_BB[BLACK_MUST_PROMOTE_PAWN_RANK]
const WHITE_MUST_PROMOTE_PAWN_BB = RANK_BB[WHITE_MUST_PROMOTE_PAWN_RANK]

