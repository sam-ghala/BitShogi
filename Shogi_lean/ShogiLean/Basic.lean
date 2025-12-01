-- import Mathlib.Tactic
-- import Mathlib.Data.Fintype.Basic
-- set_option linter.style.longLine false

/-
LEAN DEFINITIONS FOR SHOGI ENGINE FUNDAMENTALS (BITBOARD-BASED)
Author: Sam Ghalayini
-/

-- ═══════════════════════════════════════════════════════════════════════════
-- BOARD FUNDAMENTALS
-- ═══════════════════════════════════════════════════════════════════════════

-- Square Index
-- s : Fin 81
-- Unique identifier for each of the 81 squares on the board.

-- File (Column)
-- file : Fin 9
-- Vertical columns numbered 1-9 from right to left (traditional notation).

-- Rank (Row)
-- rank : Fin 9
-- Horizontal rows labeled a-i from top to bottom (Black's perspective).

-- Square Coordinates
-- sq = file * 9 + rank  (or alternative indexing scheme)
-- Bijection between (Fin 9 × Fin 9) and Fin 81.

-- Square to Coordinates
-- to_coords : Fin 81 → Fin 9 × Fin 9
-- Extracts (file, rank) from linear index.

-- Coordinates to Square
-- to_square : Fin 9 × Fin 9 → Fin 81
-- Inverse of to_coords; to_square (to_coords s) = s.

-- Coordinate Isomorphism
-- to_coords ∘ to_square = id ∧ to_square ∘ to_coords = id
-- Square indexing is a bijection.

-- Promotion Zone (Black/Sente)
-- promo_zone_black = {s | rank(s) ∈ {0, 1, 2}}
-- Top three ranks where Black's pieces may promote.

-- Promotion Zone (White/Gote)
-- promo_zone_white = {s | rank(s) ∈ {6, 7, 8}}
-- Bottom three ranks where White's pieces may promote.

-- Board Symmetry
-- flip(s) = (8 - file(s), 8 - rank(s))
-- 180° rotation; transforms position between perspectives.

-- ═══════════════════════════════════════════════════════════════════════════
-- BITBOARD REPRESENTATION
-- ═══════════════════════════════════════════════════════════════════════════

-- Bitboard
-- bb : Fin 81 → Bool  (conceptually: 81-bit integer)
-- Set representation where bit i is set iff square i is in the set.

-- Bitboard as Bitvector
-- bb : BitVec 128  (or two UInt64, since 81 > 64)
-- Implementation uses 128 bits with upper 47 unused, or split representation.

-- Split Bitboard Representation
-- bb = (lo : UInt64, hi : UInt32)  where lo holds bits 0-63, hi holds bits 64-80
-- Common implementation to handle 81 squares efficiently.

-- Empty Bitboard
-- ∅ = 0
-- No squares set; identity for union.

-- Universal Bitboard
-- U = 2⁸¹ - 1
-- All 81 squares set; identity for intersection.

-- Singleton Bitboard
-- {s} = 1 << s
-- Exactly one square set; basis for all bitboards.

-- Bitboard Membership
-- s ∈ bb ↔ (bb >> s) & 1 = 1
-- Square s is in set iff bit s is set.

-- Bitboard Union
-- A ∪ B = A | B
-- Set union via bitwise OR; squares in either set.

-- Bitboard Intersection
-- A ∩ B = A & B
-- Set intersection via bitwise AND; squares in both sets.

-- Bitboard Complement
-- Aᶜ = ~A & U
-- Set complement; squares not in A (masked to valid squares).

-- Bitboard Difference
-- A \ B = A & ~B
-- Set difference; squares in A but not B.

-- Bitboard Symmetric Difference
-- A △ B = A ^ B
-- XOR; squares in exactly one of A or B.

-- Bitboard Cardinality (Population Count)
-- |bb| = popcount(bb)
-- Number of set bits; count of squares in set.

-- Bitboard Subset
-- A ⊆ B ↔ (A & B) = A
-- All squares in A are also in B.

-- Bitboard Disjoint
-- A ∩ B = ∅ ↔ (A & B) = 0
-- No squares in common; essential for validity checks.

-- Least Significant Bit
-- lsb(bb) = bb & (-bb)
-- Isolates lowest set bit; used for iteration.

-- Bit Scan Forward
-- bsf(bb) = min {s | s ∈ bb}
-- Index of least significant set bit.

-- Bit Scan Reverse
-- bsr(bb) = max {s | s ∈ bb}
-- Index of most significant set bit.

-- Clear LSB
-- clear_lsb(bb) = bb & (bb - 1)
-- Removes lowest set bit; advances iteration.

-- Bitboard Iteration
-- while bb ≠ 0: s = bsf(bb); process(s); bb = clear_lsb(bb)
-- Enumerate all squares in set efficiently.

-- ═══════════════════════════════════════════════════════════════════════════
-- FILE AND RANK MASKS
-- ═══════════════════════════════════════════════════════════════════════════

-- File Mask
-- file_mask(f) = {s | file(s) = f}
-- All 9 squares in file f; vertical column.

-- Rank Mask
-- rank_mask(r) = {s | rank(s) = r}
-- All 9 squares in rank r; horizontal row.

-- File Mask Cardinality
-- |file_mask(f)| = 9
-- Each file contains exactly 9 squares.

-- Rank Mask Cardinality
-- |rank_mask(r)| = 9
-- Each rank contains exactly 9 squares.

-- File Mask Partition
-- ⋃_{f=0}^{8} file_mask(f) = U ∧ ∀i≠j, file_mask(i) ∩ file_mask(j) = ∅
-- Files partition the board.

-- Rank Mask Partition
-- ⋃_{r=0}^{8} rank_mask(r) = U ∧ ∀i≠j, rank_mask(i) ∩ rank_mask(j) = ∅
-- Ranks partition the board.

-- File-Rank Intersection
-- file_mask(f) ∩ rank_mask(r) = {to_square(f, r)}
-- Unique square at intersection.

-- ═══════════════════════════════════════════════════════════════════════════
-- DIAGONAL AND ANTI-DIAGONAL MASKS
-- ═══════════════════════════════════════════════════════════════════════════

-- Diagonal Index
-- diag(s) = file(s) - rank(s) + 8
-- Identifies which diagonal (↘) a square belongs to; range [0, 16].

-- Anti-Diagonal Index
-- anti_diag(s) = file(s) + rank(s)
-- Identifies which anti-diagonal (↙) a square belongs to; range [0, 16].

-- Diagonal Mask
-- diag_mask(d) = {s | diag(s) = d}
-- All squares on diagonal d.

-- Anti-Diagonal Mask
-- anti_diag_mask(d) = {s | anti_diag(s) = d}
-- All squares on anti-diagonal d.

-- Diagonal Cardinality
-- |diag_mask(d)| = 9 - |d - 8|
-- Diagonals have 1-9 squares; longest at d=8.

-- ═══════════════════════════════════════════════════════════════════════════
-- PIECE TYPES
-- ═══════════════════════════════════════════════════════════════════════════

-- Piece Type Enumeration
-- PieceType = {King, Rook, Bishop, Gold, Silver, Knight, Lance, Pawn}
-- The 8 fundamental piece types before promotion.

-- Promoted Piece Type
-- PromotedType = {Dragon, Horse, PromGold, PromSilver, PromKnight, PromLance, Tokin}
-- Promoted forms; Dragon=promoted Rook, Horse=promoted Bishop, Tokin=promoted Pawn.

-- Piece Kind (Union Type)
-- Kind = PieceType ⊕ PromotedType
-- Either base or promoted; King and Gold cannot promote.

-- Can Promote Predicate
-- can_promote(p) ↔ p ∈ {Rook, Bishop, Silver, Knight, Lance, Pawn}
-- Gold and King cannot promote.

-- Promotion Function
-- promote : PieceType → Option PromotedType
-- Maps piece to its promoted form if it can promote.

-- Demotion Function
-- demote : PromotedType → PieceType
-- Inverse of promote; captured pieces revert to base form.

-- Movement Equivalence After Promotion
-- moves(PromGold) = moves(PromSilver) = moves(PromKnight) = moves(PromLance) = moves(Tokin) = moves(Gold)
-- All minor promotions move like Gold.

-- Colored Piece
-- Piece = Color × Kind
-- Piece with ownership; Color ∈ {Black, White}.

-- ═══════════════════════════════════════════════════════════════════════════
-- PIECE MOVEMENT PATTERNS (STEP PIECES)
-- ═══════════════════════════════════════════════════════════════════════════

-- Direction Vector
-- dir : ℤ × ℤ
-- Offset (Δfile, Δrank) for a single step.

-- King Movement
-- king_dirs = {(-1,-1), (-1,0), (-1,1), (0,-1), (0,1), (1,-1), (1,0), (1,1)}
-- All 8 adjacent squares; 1 step any direction.

-- Gold Movement (Black)
-- gold_dirs_black = {(-1,-1), (-1,0), (-1,1), (0,-1), (0,1), (1,0)}
-- 6 directions: orthogonal + forward diagonals; no backward diagonals.

-- Gold Movement (White)
-- gold_dirs_white = {(-1,0), (0,-1), (0,1), (1,-1), (1,0), (1,1)}
-- Symmetric to Black; "forward" is reversed.

-- Silver Movement (Black)
-- silver_dirs_black = {(-1,-1), (-1,0), (-1,1), (1,-1), (1,1)}
-- 5 directions: forward orthogonal + all diagonals; no sideways/backward orthogonal.

-- Knight Movement (Black)
-- knight_dirs_black = {(-1,-2), (1,-2)}
-- 2 squares forward, 1 square left or right; can jump over pieces.

-- Knight Uniqueness
-- ∀s, |knight_attacks(s)| ≤ 2
-- Knight has at most 2 target squares (unlike chess knight's 8).

-- Pawn Movement (Black)
-- pawn_dir_black = {(0,-1)}
-- Single forward step only; no diagonal capture.

-- Lance Movement (Black)
-- lance_dirs_black = {(0, -k) | k ≥ 1}
-- Any number of squares forward; sliding piece on single ray.

-- Direction Reflection
-- reflect(Δf, Δr) = (Δf, -Δr)
-- Transforms Black directions to White directions.

-- Step Attack Bitboard
-- step_attacks(piece, s, color) = {s' | (s' - s) ∈ dirs(piece, color) ∧ s' valid}
-- Squares reachable by step pieces ignoring occupancy.

-- ═══════════════════════════════════════════════════════════════════════════
-- PIECE MOVEMENT PATTERNS (SLIDING PIECES)
-- ═══════════════════════════════════════════════════════════════════════════

-- Rook Directions
-- rook_dirs = {(-1,0), (1,0), (0,-1), (0,1)}
-- 4 orthogonal directions; slides until blocked.

-- Bishop Directions
-- bishop_dirs = {(-1,-1), (-1,1), (1,-1), (1,1)}
-- 4 diagonal directions; slides until blocked.

-- Ray
-- ray(s, d) = {s + k·d | k ≥ 1 ∧ (s + k·d) valid}
-- All squares from s in direction d.

-- Ray Until Blocked
-- ray_attacks(s, d, occ) = {s' ∈ ray(s,d) | ∀s'' between s and s', s'' ∉ occ}
-- Squares reachable before hitting occupancy; includes first blocker.

-- Sliding Attacks
-- slide_attacks(s, dirs, occ) = ⋃_{d ∈ dirs} ray_attacks(s, d, occ)
-- Union of all rays for sliding piece.

-- Rook Attacks
-- rook_attacks(s, occ) = slide_attacks(s, rook_dirs, occ)
-- All squares a Rook can reach from s given occupancy.

-- Bishop Attacks
-- bishop_attacks(s, occ) = slide_attacks(s, bishop_dirs, occ)
-- All squares a Bishop can reach from s given occupancy.

-- Dragon Movement (Promoted Rook)
-- dragon_attacks(s, occ) = rook_attacks(s, occ) ∪ king_step_diagonals(s)
-- Rook slides plus one-step diagonal moves.

-- Horse Movement (Promoted Bishop)
-- horse_attacks(s, occ) = bishop_attacks(s, occ) ∪ king_step_orthogonals(s)
-- Bishop slides plus one-step orthogonal moves.

-- Lance Attacks (Black)
-- lance_attacks_black(s, occ) = ray_attacks(s, (0,-1), occ)
-- Single forward ray; sliding piece restricted to one direction.

-- ═══════════════════════════════════════════════════════════════════════════
-- MAGIC BITBOARDS (SLIDING PIECE OPTIMIZATION)
-- ═══════════════════════════════════════════════════════════════════════════

-- Relevant Occupancy
-- rel_occ(s, dirs) = (⋃_{d ∈ dirs} ray(s,d)) \ edges_not_on_ray_endpoint
-- Occupancy bits that affect sliding attacks; edges often excluded.

-- Relevant Occupancy Cardinality
-- |rel_occ(s, rook_dirs)| ∈ [10, 12] for Rook
-- Number of relevant bits varies by square.

-- Magic Number
-- magic(s) : UInt64
-- Carefully chosen constant for perfect hashing of occupancy configurations.

-- Magic Index
-- magic_index(occ, s) = ((occ & rel_occ(s)) * magic(s)) >> shift(s)
-- Hash function mapping occupancy to table index.

-- Magic Table Lookup
-- magic_attacks(s, occ) = table[s][magic_index(occ, s)]
-- O(1) attack lookup after O(2^k) precomputation per square.

-- Magic Correctness
-- ∀occ, magic_attacks(s, occ) = slide_attacks(s, dirs, occ)
-- Magic bitboard yields identical results to direct computation.

-- ═══════════════════════════════════════════════════════════════════════════
-- BOARD STATE
-- ═══════════════════════════════════════════════════════════════════════════

-- Piece Placement Bitboards
-- bb_piece : Color × Kind → Bitboard
-- For each (color, kind) pair, bitboard of squares containing that piece.

-- Color Occupancy
-- occ(c) = ⋃_{k ∈ Kind} bb_piece(c, k)
-- All squares occupied by pieces of color c.

-- Total Occupancy
-- occ = occ(Black) ∪ occ(White)
-- All occupied squares.

-- Empty Squares
-- empty = occᶜ = U \ occ
-- All unoccupied squares.

-- Piece At Square
-- piece_at(s) = (c, k) where s ∈ bb_piece(c, k), or None if empty
-- Lookup function; at most one piece per square.

-- Occupancy Disjointness (Same Color)
-- ∀c, ∀k₁≠k₂, bb_piece(c, k₁) ∩ bb_piece(c, k₂) = ∅
-- No square has two pieces of same color.

-- Occupancy Disjointness (Opposite Color)
-- occ(Black) ∩ occ(White) = ∅
-- No square has pieces of both colors.

-- King Uniqueness
-- |bb_piece(c, King)| = 1
-- Each side has exactly one King.

-- Pieces In Hand
-- hand : Color × PieceType → ℕ
-- Count of captured pieces available for dropping.

-- Hand Contents
-- hand(c, p) ≥ 0
-- Non-negative count of each capturable piece type.

-- No Kings In Hand
-- hand(c, King) = 0
-- Kings cannot be captured.

-- Side To Move
-- stm : Color
-- Whose turn it is; alternates each ply.

-- Move Counter
-- ply : ℕ
-- Number of half-moves played; used for history.

-- ═══════════════════════════════════════════════════════════════════════════
-- MOVE REPRESENTATION
-- ═══════════════════════════════════════════════════════════════════════════

-- Board Move
-- BoardMove = {from : Fin 81, to : Fin 81, promote : Bool}
-- Move a piece from one square to another, optionally promoting.

-- Drop Move
-- DropMove = {piece : PieceType, to : Fin 81}
-- Place a piece from hand onto empty square.

-- Move (Union Type)
-- Move = BoardMove ⊕ DropMove
-- Either move a piece on board or drop from hand.

-- Move Source
-- source(m) = m.from for BoardMove, None for DropMove
-- Origin square if board move.

-- Move Target
-- target(m) = m.to
-- Destination square for any move.

-- Move Is Capture
-- is_capture(m, pos) ↔ m is BoardMove ∧ m.to ∈ occ(opponent)
-- Move lands on opponent's piece.

-- Move Is Promotion
-- is_promotion(m) ↔ m is BoardMove ∧ m.promote = true
-- Piece transforms to promoted form.

-- Move Is Drop
-- is_drop(m) ↔ m is DropMove
-- Piece placed from hand.

-- ═══════════════════════════════════════════════════════════════════════════
-- ATTACK GENERATION
-- ═══════════════════════════════════════════════════════════════════════════

-- Piece Attacks
-- attacks(c, k, s, occ) : Bitboard
-- Squares attacked by piece of kind k, color c, on square s.

-- All Attacks By Color
-- all_attacks(c, pos) = ⋃_{s ∈ occ(c)} attacks(c, piece_at(s).kind, s, occ)
-- Union of attacks from all pieces of one color.

-- Square Attacked By
-- attacked_by(s, c, pos) ↔ s ∈ all_attacks(c, pos)
-- Predicate: square s is under attack by color c.

-- Attackers Of Square
-- attackers(s, c, pos) = {s' | s ∈ attacks(c, piece_at(s').kind, s', occ)}
-- Set of squares containing pieces of color c attacking s.

-- ═══════════════════════════════════════════════════════════════════════════
-- CHECK AND PINS
-- ═══════════════════════════════════════════════════════════════════════════

-- King Square
-- king_sq(c) = the unique s where s ∈ bb_piece(c, King)
-- Location of color c's King.

-- In Check
-- in_check(c, pos) ↔ attacked_by(king_sq(c), opponent(c), pos)
-- King is under attack.

-- Double Check
-- double_check(c, pos) ↔ |attackers(king_sq(c), opponent(c), pos)| ≥ 2
-- King attacked by 2+ pieces; only King moves are legal.

-- Check Evasion Requirement
-- in_check(c, pos) → all legal moves must resolve check
-- Constraint on move generation when in check.

-- Pinned Piece
-- pinned(s, c, pos) ↔ ∃ attacker : slider, removing piece at s exposes King to attacker
-- Piece that cannot move freely without exposing King.

-- Pin Ray
-- pin_ray(s, c, pos) = ray from attacking slider through s to King
-- Legal moves for pinned piece restricted to this ray.

-- Absolute Pin
-- abs_pinned(s, c, pos) ↔ pinned(s, c, pos) ∧ piece_at(s) not on pin_ray endpoint
-- Piece cannot move at all (rare in Shogi due to drops).

-- ═══════════════════════════════════════════════════════════════════════════
-- LEGAL MOVE GENERATION
-- ═══════════════════════════════════════════════════════════════════════════

-- Pseudo-Legal Move
-- pseudo_legal(m, pos) ↔ m follows piece movement rules ignoring check
-- Moves before filtering for King safety.

-- Legal Move
-- legal(m, pos) ↔ pseudo_legal(m, pos) ∧ ¬in_check(stm, apply(m, pos))
-- Move doesn't leave own King in check.

-- Legal Move Set
-- legal_moves(pos) = {m | legal(m, pos)}
-- All legal moves in position.

-- Move Generation Correctness
-- ∀m ∈ generated_moves(pos), legal(m, pos)
-- Generator produces only legal moves.

-- Move Generation Completeness
-- ∀m, legal(m, pos) → m ∈ generated_moves(pos)
-- Generator produces all legal moves.

-- ═══════════════════════════════════════════════════════════════════════════
-- DROP RULES
-- ═══════════════════════════════════════════════════════════════════════════

-- Drop Target Constraint
-- drop_legal(p, s, c, pos) → s ∈ empty
-- Can only drop onto empty squares.

-- Pawn Drop File Constraint (Nifu)
-- drop_legal(Pawn, s, c, pos) → ¬∃s' ∈ file_mask(file(s)), s' ∈ bb_piece(c, Pawn)
-- Cannot drop Pawn on file already containing own unpromoted Pawn.

-- Nifu Violation
-- nifu(s, c, pos) ↔ ∃s' ≠ s, file(s') = file(s) ∧ s' ∈ bb_piece(c, Pawn)
-- Two unpromoted Pawns on same file; illegal.

-- Pawn Drop Rank Constraint
-- drop_legal(Pawn, s, Black, pos) → rank(s) ≠ 0
-- Cannot drop Pawn on last rank (no legal moves).

-- Lance Drop Rank Constraint
-- drop_legal(Lance, s, Black, pos) → rank(s) ≠ 0
-- Cannot drop Lance on last rank.

-- Knight Drop Rank Constraint
-- drop_legal(Knight, s, Black, pos) → rank(s) ∉ {0, 1}
-- Cannot drop Knight on last two ranks.

-- No Immediate Checkmate By Pawn Drop (Uchifuzume)
-- drop_legal(Pawn, s, c, pos) → ¬(is_checkmate(apply(drop(Pawn, s), pos)))
-- Dropping Pawn cannot directly cause checkmate.

-- Uchifuzume Detection
-- uchifuzume(s, c, pos) ↔ drop(Pawn, s) gives check ∧ opponent has no legal moves
-- Must verify Pawn drop doesn't mate before allowing it.

-- ═══════════════════════════════════════════════════════════════════════════
-- PROMOTION RULES
-- ═══════════════════════════════════════════════════════════════════════════

-- Promotion Zone Entry
-- enters_promo_zone(m, c) ↔ m.to ∈ promo_zone(c) ∧ m.from ∉ promo_zone(c)
-- Move crosses into promotion zone.

-- Promotion Zone Exit
-- exits_promo_zone(m, c) ↔ m.from ∈ promo_zone(c)
-- Move originates from promotion zone.

-- May Promote
-- may_promote(m, c, pos) ↔ can_promote(piece_at(m.from).kind) ∧
--                          (enters_promo_zone(m, c) ∨ exits_promo_zone(m, c))
-- Promotion is optional when moving into or within promotion zone.

-- Must Promote
-- must_promote(m, c, pos) ↔ piece has no legal moves from m.to without promoting
-- Pawn/Lance on last rank, Knight on last two ranks must promote.

-- Forced Pawn Promotion (Black)
-- piece_at(m.from) = Pawn ∧ rank(m.to) = 0 → must_promote(m, Black, pos)
-- Pawn reaching last rank must promote.

-- Forced Knight Promotion (Black)
-- piece_at(m.from) = Knight ∧ rank(m.to) ∈ {0, 1} → must_promote(m, Black, pos)
-- Knight reaching last two ranks must promote.

-- ═══════════════════════════════════════════════════════════════════════════
-- GAME TERMINATION
-- ═══════════════════════════════════════════════════════════════════════════

-- Checkmate
-- checkmate(c, pos) ↔ in_check(c, pos) ∧ legal_moves(pos) = ∅
-- In check with no legal moves; c loses.

-- Stalemate
-- stalemate(c, pos) ↔ ¬in_check(c, pos) ∧ legal_moves(pos) = ∅
-- No legal moves but not in check; extremely rare in Shogi (usually loss).

-- Resignation
-- resign(c) → opponent(c) wins
-- Player concedes; most common game ending in Shogi.

-- Repetition (Sennichite)
-- sennichite(pos, history) ↔ pos appears 4 times in history
-- Fourfold repetition; usually draw, perpetual check loses.

-- Perpetual Check
-- perpetual_check(c, history) ↔ sennichite with all repetitions being check by c
-- Giving perpetual check loses (unlike chess).

-- Impasse (Jishogi)
-- impasse(pos) ↔ both Kings in opponent's promotion zone ∧ neither can be mated
-- Mutual King invasion; resolved by piece counting.

-- Impasse Point Counting
-- points(c, pos) = 5·(Rooks + Bishops) + 1·(other pieces) for pieces in enemy camp or hand
-- Simplified; actual rules use 27-point threshold.

-- Impasse Declaration Win
-- declare_win(c, pos) ↔ impasse conditions met ∧ points(c, pos) ≥ 24 (or 28 for professional)
-- Player may claim win if conditions satisfied.

-- ═══════════════════════════════════════════════════════════════════════════
-- POSITION HASHING (ZOBRIST)
-- ═══════════════════════════════════════════════════════════════════════════

-- Zobrist Key
-- zobrist : UInt64
-- Hash of position for transposition table and repetition detection.

-- Piece-Square Zobrist
-- z_piece : Color × Kind × Fin 81 → UInt64
-- Random bitstring for each piece on each square.

-- Hand Zobrist
-- z_hand : Color × PieceType × ℕ → UInt64
-- Random bitstring for hand piece counts.

-- Side To Move Zobrist
-- z_stm : UInt64
-- XORed when Black to move (or White; convention varies).

-- Zobrist Computation
-- hash(pos) = (⊕_{(c,k,s) : pieces} z_piece(c,k,s)) ⊕ (⊕_{hand} z_hand) ⊕ (if stm=Black then z_stm else 0)
-- XOR of all component hashes.

-- Incremental Zobrist Update
-- hash(pos') = hash(pos) ⊕ Δ
-- Can update hash in O(1) per move instead of recomputing.

-- Zobrist Collision Probability
-- P(collision) ≈ n²/2⁶⁴ for n positions
-- Negligible for practical game tree sizes.

-- ═══════════════════════════════════════════════════════════════════════════
-- POSITION VALIDITY INVARIANTS
-- ═══════════════════════════════════════════════════════════════════════════

-- Valid Position
-- valid(pos) ↔ all invariants hold
-- Position reachable from starting position by legal moves.

-- One King Per Side
-- |bb_piece(c, King)| = 1 for c ∈ {Black, White}
-- Fundamental invariant.

-- No Overlapping Pieces
-- ∀c₁ c₂ k₁ k₂, (c₁,k₁)≠(c₂,k₂) → bb_piece(c₁,k₁) ∩ bb_piece(c₂,k₂) = ∅
-- At most one piece per square.

-- No Nifu
-- ∀c f, |bb_piece(c, Pawn) ∩ file_mask(f)| ≤ 1
-- At most one unpromoted Pawn per file per color.

-- No Stuck Pieces
-- ∀s ∈ bb_piece(Black, Pawn), rank(s) ≠ 0
-- No Pawns/Lances on last rank, no Knights on last two ranks.

-- Piece Conservation
-- Σ_{squares + hands} piece_count = 40
-- Total pieces (2 Kings + 38 others) conserved.

-- Opponent Not In Check
-- ¬in_check(opponent(stm), pos)
-- Side that just moved cannot leave opponent in check (they moved into it).

-- ═══════════════════════════════════════════════════════════════════════════
-- BITBOARD OPERATION PROPERTIES (THEOREMS)
-- ═══════════════════════════════════════════════════════════════════════════

-- Union Commutativity
-- A ∪ B = B ∪ A
-- Bitwise OR is commutative.

-- Union Associativity
-- (A ∪ B) ∪ C = A ∪ (B ∪ C)
-- Bitwise OR is associative.

-- Union Identity
-- A ∪ ∅ = A
-- Empty set is identity for union.

-- Union Idempotence
-- A ∪ A = A
-- OR with self is self.

-- Intersection Commutativity
-- A ∩ B = B ∩ A
-- Bitwise AND is commutative.

-- Intersection Associativity
-- (A ∩ B) ∩ C = A ∩ (B ∩ C)
-- Bitwise AND is associative.

-- Intersection Identity
-- A ∩ U = A
-- Universal set is identity for intersection.

-- Intersection Annihilation
-- A ∩ ∅ = ∅
-- AND with empty is empty.

-- Distributivity
-- A ∩ (B ∪ C) = (A ∩ B) ∪ (A ∩ C)
-- AND distributes over OR.

-- De Morgan's Laws
-- (A ∪ B)ᶜ = Aᶜ ∩ Bᶜ  and  (A ∩ B)ᶜ = Aᶜ ∪ Bᶜ
-- Complement interchanges union and intersection.

-- Double Complement
-- (Aᶜ)ᶜ = A
-- Complement is involution.

-- XOR Self-Inverse
-- A ⊕ A = ∅
-- XOR with self is zero; basis for Zobrist updates.

-- XOR Associativity
-- (A ⊕ B) ⊕ C = A ⊕ (B ⊕ C)
-- Enables incremental hash updates.

-- Cardinality of Union (Inclusion-Exclusion)
-- |A ∪ B| = |A| + |B| - |A ∩ B|
-- For disjoint sets: |A ∪ B| = |A| + |B|.

-- Subset Cardinality
-- A ⊆ B → |A| ≤ |B|
-- Subset has at most as many elements.

-- ═══════════════════════════════════════════════════════════════════════════
-- EFFICIENCY CONSIDERATIONS (COMMENTS ONLY)
-- ═══════════════════════════════════════════════════════════════════════════

-- 81-Bit Representation Trade-offs
-- Option 1: Two UInt64 (128 bits, 47 wasted)
-- Option 2: UInt64 + UInt32 (96 bits, 15 wasted)
-- Option 3: Custom 81-bit type with careful shift handling

-- SIMD Considerations
-- 128-bit operations can process both halves simultaneously
-- AVX2/AVX-512 for batch operations on multiple bitboards

-- Precomputed Attack Tables
-- Step piece attacks: 81 entries per piece type
-- Sliding pieces: magic bitboards or PEXT (BMI2)

-- Memory Layout
-- Position struct should fit in cache line (64 bytes)
-- Bitboards for each piece type vs. mailbox hybrid

-- Incremental Update Strategy
-- Maintain attack bitboards incrementally where profitable
-- vs. recomputing from scratch (often faster for Shogi's complexity)

-- Move Ordering Heuristics
-- Captures (MVV-LVA), promotions, checks first
-- History heuristic, killer moves for quiet moves

-- Transposition Table
-- Zobrist key → (depth, score, bound_type, best_move)
-- Typically 2^20 to 2^24 entries
