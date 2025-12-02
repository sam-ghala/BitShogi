# generate all legal moves for a position 

# for each position, generate
#   pseudo leagal moves that a piece could move to
#   filter to actual legal moves(doesn't leave king in check)

# is a square attacked by queried color
function is_attacked_by(state::BoardState, sq::Int, by_color::Color)::Bool
    occ = state.occupied
    c = Int(by_color)

    # can these pieces hit this square? 
    pawn_attackers = pawn_attacks(sq, opposite(by_color)) & state.pawns[c]
    if pawn_attackers != EMPTY_BB
        return true
    end

    # knight attacks
    knight_attackers = knight_attacks(sq, opposite(by_color)) & state.knights[c]
    if knight_attackers != EMPTY_BB
        return true
    end

    # silver attacks
    silver_attackers = silver_attacks(sq, opposite(by_color)) & state.silvers[c]
    if silver_attackers != EMPTY_BB
        return true
    end

    # gold attacks and prompoted gold
    gold_attackers = gold_attacks(sq, opposite(by_color))
    gold_pieces = state.golds[c] | state.promoted_pawns[c] | state.promoted_lances[c] | 
                  state.promoted_knights[c] | state.promoted_silvers[c]
    if (gold_attackers & gold_pieces) != EMPTY_BB
        return true
    end

    # king attacks
    king_attackers = KING_ATTACKS[sq] & state.kings[c]
    if king_attackers != EMPTY_BB
        return true
    end
    
    # lance attacks sliding
    lance_bb = state.lances[c]
    for lances_sq in squares(lance_bb)
        if (lance_attacks(lance_sq, occ, by_color) & square_bb(sq) != EMPTY_BB)
            return true
        end
    end

    # roooooook attacks sliding
    rook_attackers = rook_attacks(sq, occ) & (state. rooks[c] | state.promoted_rooks[c])
    if rook_attackers != EMPTY_BB
        return true
    end

    # bishop sliding 
    bishop_attackers = bishop_attacks(sq, occ) & (state.bishops[c] | state.promoted_bishops[c])
    if bishop_attackers != EMPTY_BB
        return true
    end

    # promorted rook diagonal 
    dragon_bb = state.promoted_rooks[c]
    if (KING_ATTACKS[sq] & dragon_bb) != EMPTY_BB
        return true
    end
    
    # prompoted bishop orthogonal 
    horse_bb = state.promoted_bishops[c]
    if (KING_ATTACKS[sq] & dragon_bb) != EMPTY_BB
        return true 
    end
    return false
end

# is given color in check
@inline function is_in_check(state::BoardState, color::Color)::Bool
    king_sq = state.king_sq[Int(color)]
    if king_sq == 0
        return false
    end
    return is_attacked_by(state, king_sq, opposite(color))
end

# will move leave a king in check? 
function is_legal_move(state::BoardState, move::Move, color::Color)::Bool
    test_state = copy(state)
    apply_move!(test_state, move, color)
    return !is_in_check(test_state, color)
end

# apply move to board state
function apply_move!(state::BoardState, move::Move, color::Color)::Bool
    from_sq = move_from(move)
    to_sq = move_to(move)
    pt = move_piece(move)
    is_promo = move_is_promo(move)
    captured = move_capture(move)

    if from_sq == NO_SQUARE
        # drop move
        remove_from_hand!(state, pt, color)
        place_piece!(state, to_sq, pt, color)
    else
        # board move
        if captured != NO_PIECE
            captured_pt = PieceType(captured)
            remove_piece!(state, to_sq, captured_pt, opposite(color))
            add_to_hand!(state, demote(captured_pt), color)
    end

    # move the piece 
    remove_piece!(state, from_sq, pt, color)

    #place piece
    final_pt = is_promo ? proote(pt) : pt
    place_piece!(state, to_sq, final_pt, color)
end

# is square in promotion zone
@inline function in_promotion_zone(sq::Int, color::Color)::Bool
    rank = rank_of(sq)
    if color == BLACK
        return rank in BLACK_PROMOTION_RANKS
    else
        return rank in WHITE_PROMOTION_RANKS
    end 
end

# check if piece must promote
function must_promote(pt::PieceType, to_sq::Int, color::Color)::Bool
    rank = rank_of(to_sq)

    if pt == PAWN || pt == LANCE
        # must prommote on last rank 
        if color == BLACK
            return rank == BLACK_MUST_PROMOTE_RANK
        else
            return rank == WHITE_MUST_PROMOTE_RANK
        end
    elseif pt == KNIGHT
        if color == BLACK
            return rank <= 2
        else
            return rank >= BOARD_SIZE - 1
        end
    end
    return false
end

# can this piece promote
@inline function piece_can_promote(pt::PieceType)::Bool
    return can_promote(pt) && !is_promoted(pt)
end

function generate_pawn_moves!(moves::Vector{Move}, state::BoardState, color::Color)
    
end

function generate_knight_moves!(moves::Vector{Move}, state::BoardState, color::Color)

end

function generate_silver_moves!(moves::Vector{Move}, state::BoardState, color::Color)

end

function generate_gold_moves!(moves::Vector{Move}, state::BoardState, color::Color)

end

function generate_king_moves!(moves::Vector{Move}, state::BoardState, color::Color)

end

function generate_lance_moves!(moves::Vector{Move}, state::BoardState, color::Color)

end

function generate_bishop_moves!(moves::Vector{Move}, state::BoardState, color::Color)

end

function generate_rook_moves!(moves::Vector{Move}, state::BoardState, color::Color)

end

function generate_promoted_gold_moves!(moves::Vector{Move}, state::BoardState, color::Color, piece_bb::Bitboard, pt::PieceType)

end

function generate_horse_moves!(moves::Vector{Move}, state::BoardState, color::Color)

end

function generate_dragon_moves!(moves::Vector{Move}, state::BoardState, color::Color)

end

function generate_drop_moves!(moves::Vector{Move}, state::BoardState, color::Color)
    empty = empty_squares(state)

    for idx in 1:7
        count = state.hand[Int(color)][idx]
        if count <= 0
            continue
        end

        pt = hand_index_to_piece(idx)
        valid_squares = get_valid_drop_squares(state, pt, color, empty)
        
        for to_sq in squares(valid_squares)
            push!(moves, create_drop(to_sq, pt))
        end
    end
end

function get_valid_drop_squares(state::BoardState, pt::PieceType, color::Color, empty::Bitboard)::Bitboard
    valid = empty

    if pt == PAWN
        # canot be dropped on last rank per color
        # cannot drop on same file of another pawn of same color
        if color == BLACK
            valild &= ~RANK_BB[BLACK_MUST_PROMOTE_RANK]
        else
            valid &= ~RANK_BB[WHITE_MUST_PROMOTE_RANK]
        end

        # check nifu
        own_pawns = state.pawns[Int(color)]
        for f in 1:BOARD_SIZE 
            if (own_pawns & FILE_BB[f]) != EMPTY_BB
                # already pawn in this file
                valid &= ~FILE_BB[f]
            end
        end

        # check for uchifuzume (pawn drop checkmate) handeled below

    elseif pt == LANCE
        # cannot place on last rank
        if color == BLACK
            valid &= ~RANK_BB[BLACK_MUST_PROMOTE_RANK]
        else
            valid &= ~RANK_BB[WHITE_MUST_PROMOTE_RANK]
        end

    elseif pt == KNIGHT
        # cannot go on last two ranks
        if color == BLACK 
            valid &= ~RANK_BB[1]
            if BOARD_SIZE >= 2
                valid &= ~RANK_BB[2]
            end
        else
            valid &= ~RANK_BB[BOARD_SIZE]
            if BOARD_SIZE >= 2
                valid &= ~RANK_BB[BOARD_SIZE - 1]
            end
        end
    return valid
end

function is_uchifuzume(state::BoardState, move::Move, color::Color)::Bool
    # only pawns baby
    if !move_is_drop(move) || move_piece(move) != PAWN
        return false
    end

    to_sq = move_to(move)
    enemy_king_sq = state.king_sq[Int(opposite(color))]

    # are we going to check their king
    pawn_attack = pawn_attacks(to_sq, color)
    if (pawn_attack & square_bb(enemy_king_sq)) == EMPTY_BB
        return false
    end

    # is checkmate? 
    test_state = copy(state)
    apply_move!(test_state, move, color)

    enemy_movees = generate_legal_moves(test_state, oposite(color))
    # if opponsentt has no legal moves then its illegal checkmate by pawn drop
    # sorry too overppowwwwwwwered
    return isempty(enemy_moves)
end

function generate_pseudo_legal_moves(state::BoardState, color::Color)::Vector{Move}
    
end

function generate_legal_moves(state::BoardState, color::Color)::Vector{Move}

end

function count_legal_moves(state::BoardState, color::Color)::Int

end

function is_move_legal(state::BoardState, move::Move, color::Color)::Bool

end

function is_checkmate(state::BoardState, color::Color)::Bool

end

function is_stalemate(state::BoardState, color::Color)::Bool

end

function move_to_string(move::Move)::String

end

function print_moves(moves::Vector{Move})

end

function test_move_generation()

end

test_move_generation()

# generate_legal_moves(state, color)
#         │
#         ▼
# generate_pseudo_legal_moves(state, color)
#         │
#         ▼
# Filter: is_legal_move(state, move, color)
#         │
#         ├── Copy state
#         ├── Apply move
#         └── Check if own king in check
#         │
#         ▼
# Filter: is_uchifuzume (for pawn drops)
#         │
#         ▼
# Return legal_moves