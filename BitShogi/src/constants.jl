# ===========================================================================
# constants.jl - Board configuration for variants (starting with 5x5)
# ===========================================================================
#
# PURPOSE:
#   Define all board-size-dependent constants in one place.
#   To switch variants (5x5 → 9x9), only this file changes.
#
# DESIGN PRINCIPLE:
#   Everything here should be a compile-time constant (const).
#   No functions, no logic—just values.
#
# ===========================================================================
# ---------------------------------------------------------------------------
# SECTION 1: Board Dimensions
# ---------------------------------------------------------------------------
const BOARD_SIZE::Int = 5
const NUM_SQUARES::Int = BOARD_SIZE * BOARD_SIZE
# Bitboard: Type alias for the unsigned integer that holds our bitboard
#   - UInt32 for ≤32 squares (minishogi: 25 squares ✓)
#   - UInt64 for ≤64 squares
#   - UInt128 for ≤128 squares (standard shogi: 81 squares)
const BITBOARD_TYPE = UInt32

# ---------------------------------------------------------------------------
# SECTION 2: Piece Configuration
# ---------------------------------------------------------------------------
# Minishogi pieces (per side):
#   - 1 King (K/k)
#   - 1 Gold (G/g)
#   - 1 Silver (S/s)
#   - 1 Bishop (B/b)
#   - 1 Rook (R/r)
#   - 1 Pawn (P/p)
const NUM_PIECE_TYPES = 10
const NUM_HAND_PIECE_TYPES = 5
const MAX_HAND_COUNT = 2 # can have one of your opponent's piece and your own piece in your hand
# Promoted pieces in minishogi:
#   - Pawn → Tokin (moves like Gold)
#   - Silver → Promoted Silver (moves like Gold)
#   - Bishop → Horse (Bishop + 1 square orthogonally)
#   - Rook → Dragon (Rook + 1 square diagonally)
#   - Gold and King don't promote

# ---------------------------------------------------------------------------
# SECTION 3: Promotion Zones
# ---------------------------------------------------------------------------
const PROMOTION_ZONE_SIZE = 2
const BLACK_PROMOTION_RANKS = 1:PROMOTION_ZONE_SIZE
const WHITE_PROMOTION_RANKS = (BOARD_SIZE - PROMOTION_ZONE_SIZE + 1):BOARD_SIZE
const BLACK_MUST_PROMOTE_PAWN_RANK = 1
const WHITE_MUST_PROMOTE_PAWN_RANK = 5

# ---------------------------------------------------------------------------
# SECTION 4: Starting Position
# ---------------------------------------------------------------------------
# Minishogi starting position:
#
#       1   2   3   4   5      ← Files (columns)
#     +---+---+---+---+---+
#  1  | r | b | s | g | k |    ← White's back rank (lowercase = white)
#     +---+---+---+---+---+
#  2  |   |   |   |   | p |    ← White's pawn
#     +---+---+---+---+---+
#  3  |   |   |   |   |   |    ← Empty
#     +---+---+---+---+---+
#  4  | P |   |   |   |   |    ← Black's pawn
#     +---+---+---+---+---+
#  5  | K | G | S | B | R |    ← Black's back rank (uppercase = BLACK)
#     +---+---+---+---+---+
#           Ranks (rows)
# SFEN components:
#   "rbsgk/4p/5/P4/KGSBR" = board (rank 1/rank 2/rank 3/rank 4/rank 5)
#   "b"                    = black to move
#   "-"                    = no pieces in hand
#   "1"                    = move number
const INITIAL_SFEN = "rbsgk/4p/5/P4/KGSBR b - 1"

# ---------------------------------------------------------------------------
# SECTION 5: Square Indexing
# ---------------------------------------------------------------------------
#
# 1-indexed squares with row-major ordering.
#
#       1   2   3   4   5      ← Files (columns)
#     +---+---+---+---+---+
#  1  | 1 | 2 | 3 | 4 | 5 |    ← Square indices 1-5
#     +---+---+---+---+---+
#  2  | 6 | 7 | 8 | 9 |10 |    ← Square indices 6-10
#     +---+---+---+---+---+
#  3  |11 |12 |13 |14 |15 |    ← Square indices 11-15
#     +---+---+---+---+---+
#  4  |16 |17 |18 |19 |20 |    ← Square indices 16-20
#     +---+---+---+---+---+
#  5  |21 |22 |23 |24 |25 |    ← Square indices 21-25
#     +---+---+---+---+---+
#
# Conversion formulas (1-indexed):
#   square = (rank - 1) * BOARD_SIZE + file
#   rank = ((square - 1) ÷ BOARD_SIZE) + 1
#   file = ((square - 1) % BOARD_SIZE) + 1
#
# ---------------------------------------------------------------------------
# SECTION 6: Direction Vectors
# ---------------------------------------------------------------------------
#
# Define how to move one square in each direction.
# These are offsets to add to a square index. 

const NORTH = -BOARD_SIZE # up one rank 
const SOUTH = BOARD_SIZE # down one rank
const EAST = 1 # right one file
const WEST = -1 # left one file

const NORTH_EAST = NORTH + EAST  # -4: diagonal up-right
const NORTH_WEST = NORTH + WEST  # -6: diagonal up-left
const SOUTH_EAST = SOUTH + EAST  # +6: diagonal down-right
const SOUTH_WEST = SOUTH + WEST  # +4: diagonal down-left

const ORTHOGONAL_DIRS = (NORTH, EAST, SOUTH, WEST)
const DIAGONAL_DIRS = (NORTH_EAST, NORTH_WEST, SOUTH_EAST, SOUTH_WEST)
const ALL_DIRS = (NORTH, NORTH_EAST, EAST, SOUTH_EAST, SOUTH, SOUTH_WEST, WEST, NORTH_WEST)

const EMPTY_BB = BITBOARD_TYPE(0)
const FULL_BB = BITBOARD_TYPE((1 << NUM_SQUARES) - 1)
const NO_SQUARE = 0