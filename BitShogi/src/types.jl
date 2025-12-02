# ===========================================================================
# types.jl - Core type definitions for the shogi engine
# ===========================================================================

@enum Color::UInt8 begin
    BLACK = 1
    WHITE = 2
end
# A note on @inline, don't do a function call, smiple functions like masking and bit manipulation, just add code instead of making a function call
# checking 1 million positions rank and file and test_bit has 3 million function call overheads, but code is simple enoguh to inline so there would be zero function calls
# hopefully everything I've inlined is small enough to be worth it


# Get the opposite color
# Using XOR trick: 1 ⊻ 3 = 2, 2 ⊻ 3 = 1
@inline opposite(c::Color) = Color(UInt8(c) ⊻ 0x03)

# Minishogi just won't use LANCE, KNIGHT, and their promoted versions.
#
# Values 1-8: Base pieces
# Values 9-14: Promoted pieces
# Value 0: Reserved for "no piece" / empty
#
# Promoted piece = base piece + 8
#   PAWN (1) promotes to PROMOTED_PAWN (9)
#   SILVER (4) promotes to PROMOTED_SILVER (12)

@enum PieceType::UInt8 begin
    # Base pieces (1-8)
    PAWN = 1
    LANCE = 2
    KNIGHT = 3
    SILVER = 4
    GOLD = 5
    BISHOP = 6
    ROOK = 7
    KING = 8
    
    # Promoted pieces (9-14)
    PROMOTED_PAWN = 9
    PROMOTED_LANCE = 10
    PROMOTED_KNIGHT = 11
    PROMOTED_SILVER = 12
    PROMOTED_BISHOP = 13
    PROMOTED_ROOK = 14
end

# No piece sentinel (for empty squares, no capture, etc.)
const NO_PIECE = UInt8(0)

# Check if promoted
@inline is_promoted(pt::PieceType) = UInt8(pt) > 8

# Check if can promote
@inline function can_promote(pt::PieceType)
    p = UInt8(pt)
    return p >= 1 && p <= 4 || p == 6 || p == 7  # PAWN, LANCE, KNIGHT, SILVER, BISHOP, ROOK
end

# Get the promoted version of a piece
@inline promote(pt::PieceType) = PieceType(UInt8(pt) + 8)

# Demote captured pieces
# Promoted pieces demote to base; base pieces stay base
@inline function demote(pt::PieceType)
    p = UInt8(pt)
    return p > 8 ? PieceType(p - 8) : pt
end

# Check if its a sliding piece (Rook, Bishop, Lance, and their promoted versions)
@inline function is_slider(pt::PieceType)
    p = UInt8(pt)
    return p == 2 || p == 6 || p == 7 || # LANCE, BISHOP, ROOK
           p == 13 || p == 14 # PROMOTED_BISHOP, PROMOTED_ROOK
end

# Promoted to Gold
@inline function moves_like_gold(pt::PieceType)
    p = UInt8(pt)
    return p == 5 || (p >= 9 && p <= 12) # GOLD, PROMOTED_PAWN/LANCE/KNIGHT/SILVER
end

# Pieces available in minishogi
const MINISHOGI_PIECES = (PAWN, SILVER, GOLD, BISHOP, ROOK, KING,
                          PROMOTED_PAWN, PROMOTED_SILVER, PROMOTED_BISHOP, PROMOTED_ROOK)

# Pieces that can be in hand (not King, and demoted versions only)
const HAND_PIECE_TYPES = (PAWN, LANCE, KNIGHT, SILVER, GOLD, BISHOP, ROOK)
const MINISHOGI_HAND_PIECE_TYPES = (PAWN, SILVER, GOLD, BISHOP, ROOK)

# Convert (rank, file) to square index (both 1-indexed)
@inline square_index(rank::Int, file::Int) = (rank - 1) * BOARD_SIZE + file

# Get rank from square index (1-indexed)
@inline rank_of(sq::Int) = ((sq - 1) ÷ BOARD_SIZE) + 1

# Get file from square index (1-indexed)
@inline file_of(sq::Int) = ((sq - 1) % BOARD_SIZE) + 1

# check if its a valid square index
@inline is_valid_square(sq::Int) = 1 <= sq <= NUM_SQUARES

# Moves are packed into a single 32-bit integer for efficiency.
# This layout supports boards up to 127 squares.
# ┌──────┬───────┬──┬───────┬──────┬──────┐
# │unused│capture│pr│ piece │ to   │ from │
# └──────┴───────┴──┴───────┴──────┴──────┘
#          4 bits  1   4 bits  7 bits 7 bits
# Bit layout:
#   bits 0-6:   from_sq (0-127; 0 = drop, 1-81 = board squares)
#   bits 7-13:  to_sq (1-81)
#   bits 14-17: piece_type (1-14)
#   bit 18:     promotion flag (0 = no, 1 = yes)
#   bits 19-22: captured piece type (0 = no capture, 1-14 = piece type)
#   bits 23-31: unused

const Move = UInt32

# Bit positions and masks
const MOVE_FROM_SHIFT = 0
const MOVE_TO_SHIFT = 7
const MOVE_PIECE_SHIFT = 14
const MOVE_PROMO_SHIFT = 18
const MOVE_CAPTURE_SHIFT = 19

const MOVE_FROM_MASK = UInt32(0x7F)
const MOVE_TO_MASK = UInt32(0x7F) << 7
const MOVE_PIECE_MASK = UInt32(0x0F) << 14
const MOVE_PROMO_MASK = UInt32(0x01) << 18
const MOVE_CAPTURE_MASK = UInt32(0x0F) << 19

# create a regular move
@inline function create_move(from_sq::Int, to_sq::Int, piece::PieceType, promotion::Bool, captured::UInt8)::Move
    return (UInt32(from_sq) << MOVE_FROM_SHIFT) |
           (UInt32(to_sq) << MOVE_TO_SHIFT) |
           (UInt32(piece) << MOVE_PIECE_SHIFT) |
           (UInt32(promotion) << MOVE_PROMO_SHIFT) | 
           (UInt32(captured) << MOVE_CAPTURE_SHIFT)
end

# create a drop move (from_sq=0)
@inline function create_drop(to_sq::Int, piece::PieceType)::Move
    return (UInt32(NO_SQUARE) << MOVE_FROM_SHIFT) |
           (UInt32(to_sq) << MOVE_TO_SHIFT) | 
           (UInt32(piece) << MOVE_PIECE_SHIFT)
end

const NULL_MOVE = Move(0)

@inline move_from(m::Move)::Int = Int((m >> MOVE_FROM_SHIFT) & 0x7F)
@inline move_to(m::Move)::Int = Int((m >> MOVE_TO_SHIFT) & 0x7F)
@inline move_piece(m::Move)::PieceType = PieceType((m >> MOVE_PIECE_SHIFT) & 0x0F)
@inline move_is_promotion(m::Move)::Bool = ((m >> MOVE_PROMO_SHIFT) & 0x01) != 0
@inline move_capture(m::Move)::UInt8 = UInt8((m >> MOVE_CAPTURE_SHIFT) & 0x0F)

@inline move_is_drop(m::Move)::Bool = move_from(m) == NO_SQUARE
@inline move_is_capture(m::Move)::Bool = move_capture(m) != NO_PIECE

# piece on square
# bits 0-3 = piece type 0-14, bit 4 = color (0=black, 1=white)
const Piece = UInt8 
const PIECE_TYPE_MASK = UInt8(0x0F)
const PIECE_COLOR_BIT = UInt8(0x10)

@inline function create_piece(pt::PieceType, c::Color)::Piece
    return UInt8(pt) | (Uint8(c - 1) << 4)
end

@inline piece_type(p::Piece)::PieceType = PieceType(p & PIECE_TYPE_MASK)
@inline piece_color(p::Piece)::Color = Color((p >> 4) + 1)

const NO_PIECE_VALUE = Piece(0)

@enum GameStatus::UInt8 begin
    ONGOING = 0
    BLACK_WINS = 1
    WHITE_WINS = 2
    DRAW_REPETITION = 3
    DRAW_IMPASSE = 4
    DRAW_STALEMATE = 5
end

# SFEN mappings
const SFEN_TO_PIECE = Dict{Char, Tuple{PieceType, Color}}(
    'P' => (PAWN, BLACK),
    'L' => (LANCE, BLACK),
    'N' => (KNIGHT, BLACK),
    'S' => (SILVER, BLACK),
    'G' => (GOLD, BLACK),
    'B' => (BISHOP, BLACK),
    'R' => (ROOK, BLACK),
    'K' => (KING, BLACK),
    'p' => (PAWN, WHITE),
    'l' => (LANCE, WHITE),
    'n' => (KNIGHT, WHITE),
    's' => (SILVER, WHITE),
    'g' => (GOLD, WHITE),
    'b' => (BISHOP, WHITE),
    'r' => (ROOK, WHITE),
    'k' => (KING, WHITE),
)

const PIECE_TO_SFEN = Dict{Tuple{PieceType, Color}, Char}(
    (PAWN, BLACK)   => 'P',
    (LANCE, BLACK)  => 'L',
    (KNIGHT, BLACK) => 'N',
    (SILVER, BLACK) => 'S',
    (GOLD, BLACK)   => 'G',
    (BISHOP, BLACK) => 'B',
    (ROOK, BLACK)   => 'R',
    (KING, BLACK)   => 'K',
    (PAWN, WHITE)   => 'p',
    (LANCE, WHITE)  => 'l',
    (KNIGHT, WHITE) => 'n',
    (SILVER, WHITE) => 's',
    (GOLD, WHITE)   => 'g',
    (BISHOP, WHITE) => 'b',
    (ROOK, WHITE)   => 'r',
    (KING, WHITE)   => 'k',
)

const PROMOTED_SFEN_PREFIX = '+' # +P, +R, +l

