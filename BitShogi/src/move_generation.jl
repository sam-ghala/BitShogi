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
    for lance_sq in squares(lance_bb)
        if (lance_attacks(lance_sq, occ, by_color) & square_bb(sq) != EMPTY_BB)
            return true
        end
    end

    # roooooook attacks sliding
    rook_attackers = rook_attacks(sq, occ) & (state.rooks[c] | state.promoted_rooks[c])
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
    if (KING_ATTACKS[sq] & horse_bb) != EMPTY_BB
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
function apply_move!(state::BoardState, move::Move, color::Color)
    from_sq = move_from(move)
    to_sq = move_to(move)
    pt = move_piece(move)
    is_promo = move_is_promotion(move)
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
        
        # remove piece 
        remove_piece!(state, from_sq, pt, color)
        
        # place piece 
        final_pt = is_promo ? promote(pt) : pt
        place_piece!(state, to_sq, final_pt, color)
    end
    
   # update bitboards 
    update_occupied!(state)
end

# is square in promotion zone
@inline function in_promotion_zone(sq::Int, color::Color, pt::PieceType=PAWN)::Bool
    rank = rank_of(sq)
    if color == BLACK
        if pt == KNIGHT
            return rank <= 2
        end
        return rank in BLACK_PROMOTION_RANKS
    else
        if pt == KNIGHT
            return rank <= 2
        end
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
    pawns = state.pawns[Int(color)]
    own_pieces = state.occupied_by[Int(color)]
    enemy_pieces = state.occupied_by[Int(opposite(color))]
    # if pawns == EMPTY_BB
    #     return
    # end
    for from_sq in squares(pawns) 
        # get their attacks
        targets = pawn_attacks(from_sq, color)
        # move to empty of capture
        valid_targets = targets & ~own_pieces

        for to_sq in squares(valid_targets)
            # check capture
            captured = UInt8(NO_PIECE)
            if test_bit(enemy_pieces, to_sq)
                piece_info = piece_at(state, to_sq)
                if piece_info !== nothing
                    captured = UInt8(piece_info[1])
                end
            end

            # check promotion 
            can_promo = in_promotion_zone(from_sq, color) || in_promotion_zone(to_sq, color)
            must_promo = must_promote(PAWN, to_sq, color)

            if must_promo
                # must promote that guy, its time, hes been here for years
                push!(moves, create_move(from_sq, to_sq, PAWN, true, captured))
            elseif can_promo
                push!(moves, create_move(from_sq, to_sq, PAWN, true, captured))
                push!(moves, create_move(from_sq, to_sq, PAWN, false, captured))
            else
                # sorry cannot promote that boy 
                push!(moves, create_move(from_sq, to_sq, PAWN, false, captured))
            end
        end
    end
end

function generate_knight_moves!(moves::Vector{Move}, state::BoardState, color::Color)
    knights = state.knights[Int(color)]
    own_pieces = state.occupied_by[Int(color)]
    enemy_pieces = state.occupied_by[Int(opposite(color))]
    # if knights == EMPTY_BB
    #     return
    # end
    for from_sq in squares(knights)
        # where are the knights
        targets = knight_attacks(from_sq, color)
        valid_targets = targets & ~own_pieces
        
        for to_sq in squares(valid_targets)
            captured = UInt8(NO_PIECE)
            if test_bit(enemy_pieces, to_sq)
                piece_info = piece_at(state, to_sq)
                if piece_info !== nothing
                    captured = UInt8(piece_info[1])
                end
            end
            
            can_promo = in_promotion_zone(from_sq, color) || in_promotion_zone(to_sq, color)
            must_promo = must_promote(KNIGHT, to_sq, color)
            
            if must_promo
                push!(moves, create_move(from_sq, to_sq, KNIGHT, true, captured))
            elseif can_promo
                push!(moves, create_move(from_sq, to_sq, KNIGHT, true, captured))
                push!(moves, create_move(from_sq, to_sq, KNIGHT, false, captured))
            else
                push!(moves, create_move(from_sq, to_sq, KNIGHT, false, captured))
            end
        end
    end
end

function generate_silver_moves!(moves::Vector{Move}, state::BoardState, color::Color)
    silvers = state.silvers[Int(color)]
    own_pieces = state.occupied_by[Int(color)]
    enemy_pieces = state.occupied_by[Int(opposite(color))]
    # if silvers == EMPTY_BB
    #     return
    # end
    for from_sq in squares(silvers)
        targets = silver_attacks(from_sq, color)
        valid_targets = targets & ~own_pieces
        
        for to_sq in squares(valid_targets)
            captured = UInt8(NO_PIECE)
            if test_bit(enemy_pieces, to_sq)
                piece_info = piece_at(state, to_sq)
                if piece_info !== nothing
                    captured = UInt8(piece_info[1])
                end
            end
            
            can_promo = in_promotion_zone(from_sq, color) || in_promotion_zone(to_sq, color)
            
            if can_promo
                push!(moves, create_move(from_sq, to_sq, SILVER, true, captured))
                push!(moves, create_move(from_sq, to_sq, SILVER, false, captured))
            else
                push!(moves, create_move(from_sq, to_sq, SILVER, false, captured))
            end
        end
    end
end

function generate_gold_moves!(moves::Vector{Move}, state::BoardState, color::Color)
    golds = state.golds[Int(color)]
    own_pieces = state.occupied_by[Int(color)]
    enemy_pieces = state.occupied_by[Int(opposite(color))]
    # if golds == EMPTY_BB
    #     return
    # end
    for from_sq in squares(golds)
        targets = gold_attacks(from_sq, color)
        valid_targets = targets & ~own_pieces
        
        for to_sq in squares(valid_targets)
            captured = UInt8(NO_PIECE)
            if test_bit(enemy_pieces, to_sq)
                piece_info = piece_at(state, to_sq)
                if piece_info !== nothing
                    captured = UInt8(piece_info[1])
                end
            end
            
            # Gold cannot promote
            push!(moves, create_move(from_sq, to_sq, GOLD, false, captured))
        end
    end
end

function generate_king_moves!(moves::Vector{Move}, state::BoardState, color::Color)
    king_sq = state.king_sq[Int(color)]
    if king_sq == 0
        return
    end
    
    own_pieces = state.occupied_by[Int(color)]
    enemy_pieces = state.occupied_by[Int(opposite(color))]
    
    targets = KING_ATTACKS[king_sq]
    valid_targets = targets & ~own_pieces
    
    for to_sq in squares(valid_targets)
        captured = UInt8(NO_PIECE)
        if test_bit(enemy_pieces, to_sq)
            piece_info = piece_at(state, to_sq)
            if piece_info !== nothing
                captured = UInt8(piece_info[1])
            end
        end
        
        # King cannot promote
        push!(moves, create_move(king_sq, to_sq, KING, false, captured))
    end
end

function generate_lance_moves!(moves::Vector{Move}, state::BoardState, color::Color)
    lances = state.lances[Int(color)]
    own_pieces = state.occupied_by[Int(color)]
    enemy_pieces = state.occupied_by[Int(opposite(color))]
    occ = state.occupied
    # if lances == EMPTY_BB
    #     return
    # end
    for from_sq in squares(lances)
        targets = lance_attacks(from_sq, occ, color)
        valid_targets = targets & ~own_pieces
        
        for to_sq in squares(valid_targets)
            captured = UInt8(NO_PIECE)
            if test_bit(enemy_pieces, to_sq)
                piece_info = piece_at(state, to_sq)
                if piece_info !== nothing
                    captured = UInt8(piece_info[1])
                end
            end
            
            can_promo = in_promotion_zone(from_sq, color) || in_promotion_zone(to_sq, color)
            must_promo = must_promote(LANCE, to_sq, color)
            
            if must_promo
                push!(moves, create_move(from_sq, to_sq, LANCE, true, captured))
            elseif can_promo
                push!(moves, create_move(from_sq, to_sq, LANCE, true, captured))
                push!(moves, create_move(from_sq, to_sq, LANCE, false, captured))
            else
                push!(moves, create_move(from_sq, to_sq, LANCE, false, captured))
            end
        end
    end
end

function generate_bishop_moves!(moves::Vector{Move}, state::BoardState, color::Color)
    bishops = state.bishops[Int(color)]
    own_pieces = state.occupied_by[Int(color)]
    enemy_pieces = state.occupied_by[Int(opposite(color))]
    occ = state.occupied
    # if bishops == EMPTY_BB
    #     return
    # end
    for from_sq in squares(bishops)
        targets = bishop_attacks(from_sq, occ)
        valid_targets = targets & ~own_pieces
        
        for to_sq in squares(valid_targets)
            captured = UInt8(NO_PIECE)
            if test_bit(enemy_pieces, to_sq)
                piece_info = piece_at(state, to_sq)
                if piece_info !== nothing
                    captured = UInt8(piece_info[1])
                end
            end
            
            can_promo = in_promotion_zone(from_sq, color) || in_promotion_zone(to_sq, color)
            
            if can_promo
                push!(moves, create_move(from_sq, to_sq, BISHOP, true, captured))
                push!(moves, create_move(from_sq, to_sq, BISHOP, false, captured))
            else
                push!(moves, create_move(from_sq, to_sq, BISHOP, false, captured))
            end
        end
    end
end

function generate_rook_moves!(moves::Vector{Move}, state::BoardState, color::Color)
    rooks = state.rooks[Int(color)]
    own_pieces = state.occupied_by[Int(color)]
    enemy_pieces = state.occupied_by[Int(opposite(color))]
    occ = state.occupied
    # if rooks == EMPTY_BB
    #     return
    # end
    for from_sq in squares(rooks)
        targets = rook_attacks(from_sq, occ)
        valid_targets = targets & ~own_pieces
        
        for to_sq in squares(valid_targets)
            captured = UInt8(NO_PIECE)
            if test_bit(enemy_pieces, to_sq)
                piece_info = piece_at(state, to_sq)
                if piece_info !== nothing
                    captured = UInt8(piece_info[1])
                end
            end
            
            can_promo = in_promotion_zone(from_sq, color) || in_promotion_zone(to_sq, color)
            
            if can_promo
                push!(moves, create_move(from_sq, to_sq, ROOK, true, captured))
                push!(moves, create_move(from_sq, to_sq, ROOK, false, captured))
            else
                push!(moves, create_move(from_sq, to_sq, ROOK, false, captured))
            end
        end
    end
end

function generate_promoted_gold_moves!(moves::Vector{Move}, state::BoardState, color::Color, 
                                        piece_bb::Bitboard, pt::PieceType)
    own_pieces = state.occupied_by[Int(color)]
    enemy_pieces = state.occupied_by[Int(opposite(color))]
    # if piece_bb == EMPTY_BB
    #     return
    # end
    for from_sq in squares(piece_bb)
        targets = gold_attacks(from_sq, color)
        valid_targets = targets & ~own_pieces
        
        for to_sq in squares(valid_targets)
            captured = UInt8(NO_PIECE)
            if test_bit(enemy_pieces, to_sq)
                piece_info = piece_at(state, to_sq)
                if piece_info !== nothing
                    captured = UInt8(piece_info[1])
                end
            end
            
            # highest rank, cannot promote any further 
            push!(moves, create_move(from_sq, to_sq, pt, false, captured))
        end
    end
end


function generate_horse_moves!(moves::Vector{Move}, state::BoardState, color::Color)
    # bishop + king moves = horse 
    horses = state.promoted_bishops[Int(color)]
    own_pieces = state.occupied_by[Int(color)]
    enemy_pieces = state.occupied_by[Int(opposite(color))]
    # if horses == EMPTY_BB
    #     return
    # end
    occ = state.occupied
    for from_sq in squares(horses)
        targets = horse_attacks(from_sq, occ)
        valid_targets = targets & ~own_pieces
        
        for to_sq in squares(valid_targets)
            captured = UInt8(NO_PIECE)
            if test_bit(enemy_pieces, to_sq)
                piece_info = piece_at(state, to_sq)
                if piece_info !== nothing
                    captured = UInt8(piece_info[1])
                end
            end
            push!(moves, create_move(from_sq, to_sq, PROMOTED_BISHOP, false, captured))
        end
    end
end

function generate_dragon_moves!(moves::Vector{Move}, state::BoardState, color::Color)
    # rook + king moves = dragon 
    dragons = state.promoted_rooks[Int(color)]
    own_pieces = state.occupied_by[Int(color)]
    enemy_pieces = state.occupied_by[Int(opposite(color))]
    occ = state.occupied
    # if dragons == EMPTY_BB
    #     return
    # end
    for from_sq in squares(dragons)
        targets = dragon_attacks(from_sq, occ)
        valid_targets = targets & ~own_pieces
        
        for to_sq in squares(valid_targets)
            captured = UInt8(NO_PIECE)
            if test_bit(enemy_pieces, to_sq)
                piece_info = piece_at(state, to_sq)
                if piece_info !== nothing
                    captured = UInt8(piece_info[1])
                end
            end
            
            push!(moves, create_move(from_sq, to_sq, PROMOTED_ROOK, false, captured))
        end
    end
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
            valid &= ~RANK_BB[BLACK_MUST_PROMOTE_RANK]
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

    enemy_moves = generate_legal_moves(test_state, opposite(color))
    # if opponsentt has no legal moves then its illegal checkmate by pawn drop
    # sorry too overppowwwwwwwered
    return isempty(enemy_moves)
end

function generate_pseudo_legal_moves(state::BoardState, color::Color)::Vector{Move}
    moves = Move[]

    # non-sliding pieces
    generate_pawn_moves!(moves, state, color)
    generate_knight_moves!(moves, state, color)
    generate_silver_moves!(moves, state, color)
    generate_gold_moves!(moves, state, color)
    generate_king_moves!(moves, state, color)
    
    # sliding pieces
    generate_lance_moves!(moves, state, color)
    generate_bishop_moves!(moves, state, color)
    generate_rook_moves!(moves, state, color)

    # promoted soldiers
    generate_promoted_gold_moves!(moves, state, color, state.promoted_pawns[Int(color)], PROMOTED_PAWN)
    generate_promoted_gold_moves!(moves, state, color, state.promoted_lances[Int(color)], PROMOTED_LANCE)
    generate_promoted_gold_moves!(moves, state, color, state.promoted_knights[Int(color)], PROMOTED_KNIGHT)
    generate_promoted_gold_moves!(moves, state, color, state.promoted_silvers[Int(color)], PROMOTED_SILVER)
    generate_horse_moves!(moves, state, color)
    generate_dragon_moves!(moves, state, color)

    # drop moves from the hand
    generate_drop_moves!(moves, state, color)

    return moves
end

function generate_legal_moves(state::BoardState, color::Color)::Vector{Move}
    pseudo_legal = generate_pseudo_legal_moves(state, color)
    legal_moves = Move[]

    for move in pseudo_legal
        # check if king is in check, uchifuzume
        if is_legal_move(state, move, color)
            if move_is_drop(move) && move_piece(move) == PAWN
                if is_uchifuzume(state, move, color)
                    continue
                end
            end
            push!(legal_moves, move)
        end
    end

    return legal_moves
end

function count_legal_moves(state::BoardState, color::Color)::Int
    return length(generate_legal_moves(state, color))
end

function is_move_legal(state::BoardState, move::Move, color::Color)::Bool
    legal_moves = generate_legal_moves(state, color)
    return move in legal_moves
end

function is_checkmate(state::BoardState, color::Color)::Bool
    if !is_in_check(state, color)
        return false
    end
    return isempty(generate_legal_moves(state, color))
end

function is_stalemate(state::BoardState, color::Color)::Bool
    if is_in_check(state, color)
        return false
    end
    return isempty(generate_legal_moves(state, color))
end

function move_to_string(move::Move)::String
    from_sq = move_from(move)
    to_sq = move_to(move)
    pt = move_piece(move)
    promo = move_is_promotion(move)

    piece_chars = Dict(
        PAWN => "P", LANCE => "L", KNIGHT => "N", SILVER => "S",
        GOLD => "G", BISHOP => "B", ROOK => "R", KING => "K",
        PROMOTED_PAWN => "+P", PROMOTED_LANCE => "+L", PROMOTED_KNIGHT => "+N",
        PROMOTED_SILVER => "+S", PROMOTED_BISHOP => "+B", PROMOTED_ROOK => "+R"
    )

    char = get(piece_chars, pt, "?")

    if from_sq == NO_SQUARE
        # drop move
        to_file = file_of(to_sq)
        to_rank = rank_of(to_sq)
        return "$(piece)*$(to_file)$(Char('a' + to_rank - 1))"
    else
        # board move
        from_file = file_of(from_sq)
        from_rank = rank_of(from_sq)
        to_file = file_of(to_sq)
        to_rank = rank_of(to_sq)

        move_str =  "$(from_file)$(Char('a' + from_rank - 1))-$(to_file)$(Char('a' + to_rank - 1))"
        if promo
            move_str *= "+"
        end
        return move_str
    end
end

function print_moves(moves::Vector{Move})
    println("Total moves: $(length(moves))")
    for (i, move) in enumerate(moves)
        println(" $i. $(move_to_string(move))")
    end
end

function test_move_generation()
     println("Testing move generation...")
    
    if !MAGICS_INITIALIZED[]
        init_all_magics!()
    end
    # set init pos 
    state = initial_position()
    print_board(state)
    
    # blacks moves 
    println("\nBlack's legal moves from initial position:")
    black_moves = generate_legal_moves(state, BLACK)
    print_moves(black_moves)
    
    # whites moves 
    println("\nWhite's legal moves from initial position:")
    white_moves = generate_legal_moves(state, WHITE)
    print_moves(white_moves)
    
    # any in check 
    println("\nCheck detection:")
    println("  Black in check: $(is_in_check(state, BLACK))")
    println("  White in check: $(is_in_check(state, WHITE))")
    
    # make a move, i dare you, then check 
    if !isempty(black_moves)
        move = black_moves[1]
        println("\nMaking move: $(move_to_string(move))")
        apply_move!(state, move, BLACK)
        print_board(state)
        
        # response 
        println("\nWhite's legal moves after Black's move:")
        white_moves = generate_legal_moves(state, WHITE)
        print_moves(white_moves)
    end
    
    println("\nMove generation tests complete!")
end

# test_move_generation()

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
