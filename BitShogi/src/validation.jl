# validating moves without generating all legal moves
# rule enforcement for model and user
# game termination 


# USI (Universal Shogi Interface) parsing
# USI move format:
#   Board moves: <from><to>[+]  e.g., "7g7f" or "2b3c+"
#   Drop moves:  <PIECE>*<to>   e.g., "P*5e" or "G*3b"
#
# For minishogi (5x5), we use:
#   Files: 1-5 (left to right)
#   Ranks: a-e (top to bottom, rank 1 = 'a', rank 5 = 'e')
#
# Examples:
#   "1d1c"  = move from (rank 4, file 1) to (rank 3, file 1)
#   "1d1c+" = same move with promotion
#   "P*3c"  = drop pawn on (rank 3, file 3)

const PIECE_CHAR_TO_TYPE = Dict(
    'P' => PAWN, 'L' => LANCE, 'N' => KNIGHT, 'S' => SILVER,
    'G' => GOLD, 'B' => BISHOP, 'R' => ROOK, 'K' => KING
)

const PIECE_TYPE_TO_CHAR = Dict(
    PAWN => 'P', LANCE => 'L', KNIGHT => 'N', SILVER => 'S',
    GOLD => 'G', BISHOP => 'B', ROOK => 'R', KING => 'K',
    PROMOTED_PAWN => 'P', PROMOTED_LANCE => 'L', PROMOTED_KNIGHT => 'N',
    PROMOTED_SILVER => 'S', PROMOTED_BISHOP => 'B', PROMOTED_ROOK => 'R'
)

# parse square from usi index 
function parse_square(notation::AbstractString)::Union{Int, Nothing}
    if length(notation) != 2
        return nothing
    end

    file_char = notation[1]
    rank_char = notation[2]

    # file is a digit 
    if !isdigit(file_char)
        return nothing
    end
    file = parse(Int, file_char)

    # rank is a letter 
    if !isletter(rank_char)
        return nothing
    end

    rank = Int(lowercase(rank_char)) - Int('a') + 1

    # validate bounds 
    if file < 1 || file > BOARD_SIZE || rank < 1 || rank > BOARD_SIZE
        return nothing
    end

    return square_index(rank, file)
end

# convert square to "numLetter" notation
function square_to_string(sq::Int)::String
    rank = rank_of(sq)
    file = file_of(sq)
    return "$(file)$(Char('a' + rank - 1))"
end

function parse_move(notation::AbstractString, state::BoardState, color::Color)::Union{Move, Nothing}
    notation = strip(notation)

    if length(notation) < 3
        return nothing 
    end

    # is drop move 
    if length(notation) >= 3 && notation[2] == '*'
        return parse_drop_move(notation, state, color)
    end
    
    # board move 
    return parse_board_move(notation, state, color)
end

# drop move
function parse_drop_move(notation::AbstractString, state::BoardState, color::Color)::Union{Move, Nothing}
    piece_char = uppercase(notation[1])

    if !haskey(PIECE_CHAR_TO_TYPE, piece_char)
        return nothing
    end

    pt = PIECE_CHAR_TO_TYPE[piece_char]

    if pt == KING
        return nothing 
    end

    # destination
    to_sq = parse_square(notation[3:end])
    if to_sq === nothing 
        return nothing 
    end
    # piece in hand?
    if !has_in_hand(state, pt, color)
        return nothing
    end

    return create_drop(to_sq, pt)
end

# board move 
function parse_board_move(notation::AbstractString, state::BoardState, color::Color)::Union{Move, Nothing}
    is_promo = endswith(notation, "+")
    move_str = is_promo ? notation[1:end-1] : notation

    if length(move_str) != 4
        return nothing 
    end

    from_sq = parse_square(move_str[1:2])
    to_sq = parse_square(move_str[3:4])

    if from_sq === nothing || to_sq === nothing
        return nothing 
    end

    piece_info = piece_at(state, from_sq)
    if piece_info === nothing
        return nothing 
    end

    pt, piece_color = piece_info
    if piece_color != color
        return nothing
    end

    # check for capture
    captured = UInt8(NO_PIECE)
    target_info = piece_at(state, to_sq)
    if target_info !== nothing
        target_pt, target_color = target_info
        if target_color == color
            return nothing
        end
        captured = UInt8(target_pt)
    end

    return create_move(from_sq, to_sq, pt, is_promo, captured)
end

# is move legal 
function validate_move(state::BoardState, move::Move, color::Color)::Tuple{Bool, String}
    from_sq = move_from(move)
    to_sq = move_to(move)
    pt = move_piece(move)
    is_promo = move_is_promotion(move)

    if to_sq < 1 || to_sq > NUM_SQUARES
        return (false, "Invalid dest square")
    end

    if move_is_drop(move)
        return validate_drop_move(state, move, color)
    else
        return validate_board_move(state, move, color)
    end
end

# validate drop move
function validate_drop_move(state::BoardState, move::Move, color::Color)::Tuple{Bool, String}
    to_sq = move_to(move)
    pt = move_piece(move)

    # check in hand
    if !has_in_hand(state, pt, color)
        return (false, "No $(pt) in hand")
    end

    if !is_empty_sq(state, to_sq)
        return (false, "Destination square is occupied")
    end

    # check drop restrictions
    rank = rank_of(to_sq)
    # pawn restrictions 
    if pt == PAWN
        if (color == BLACK && rank == BLACK_MUST_PROMOTE_RANK) ||
           (color == WHITE && rank == WHITE_MUST_PROMOTE_RANK)
           return (false, "Cannot drop pawn on last rank")
        end

        # nifu check 
        file = file_of(to_sq)
        own_pawns = state.pawns[Int(color)]
        if (own_pawns & FILE_BB[file]) != EMPTY_BB
            return (false, "Nifu, two pawns already on file")
        end
    end
    # lance restrictions 
        if pt == LANCE
        if (color == BLACK && rank == BLACK_MUST_PROMOTE_RANK) ||
           (color == WHITE && rank == WHITE_MUST_PROMOTE_RANK)
            return (false, "Cannot drop lance on last rank")
        end
    end
    # knight restrictions 
    if pt == KNIGHT 
        if color == BLACK && rank <= 2
            return (false, "Cannot drop knight on last two ranks")
        elseif color == WHITE && rank >= BOARD_SIZE - 1
            return (false, "Cannot drop knight on last two ranks")
        end
    end

    # check if move leaves king in check 
    test_state = copy(state)
    apply_move!(test_state, move, color)
    if is_in_check(test_state, color)
        return (false, "Move leaves king in check")
    end

    # check uchifuzume
    if pt == PAWN && is_uchifuzume(state, move, color)
        return (false, "drop pawn makes illegal checkmate")
    end

    return (true, "Valid move")
end

# validate board move
function validate_board_move(state::BoardState, move::Move, color::Color)::Tuple{Bool, String}
    from_sq = move_from(move)
    to_sq = move_to(move)
    pt = move_piece(move)
    is_promo = move_is_promotion(move)
    # check square bounds
    if from_sq < 1 || from_sq > NUM_SQUARES
        return (false, "Invalid source square")
    end
    # check pirce exists at from_sq
    piece_info = piece_at(state, from_sq)
    if piece_info === nothing
        return (false, "No piece at source square")
    end

    actual_pt, actual_color = piece_info
    if actual_color != color
        return (false, "piece type mismatch")
    end
    if actual_pt != pt
        return (false, "Piece type mismatch")
    end

    #check dest not occupied by own color
    if is_occupied_by(state, to_sq, color)
        return (false, "Cannot capture own piece")
    end

    # check piece can read destination 
    if !can_piece_reach(state, from_sq, to_sq, pt, color)
        return (false, "Piece cannot reach destination")
    end

    # check proomotion validaity 
    if is_promo
        if !can_promote(pt)
            return (false, "This piece cannot promote")
        end
        if is_promoted(pt)
            return (false, "This piece is already promoted")
        end
        if !in_promotion_zone(from_sq, color) && !in_promotion_zone(to_sq, color)
            return (false, "Not in promotion zone")
        end
    else
        if must_promote(pt, to_sq, color)
            return (false, "Promotion is mandatory for this move")
        end
    end

    # check if move leaves king in check
    test_state = copy(state)
    apply_move!(test_state, move, color)
    if is_in_check(test_state, color)
        return (false, "Move leaves king in check")
    end

    return (true, "Valid move")
end

# can this piece physically reach it where its trying to go
function can_piece_reach(state::BoardState, from_sq::Int, to_sq::Int, pt::PieceType, color::Color)::Bool
    occ = state.occupied

    # bet attack bitbaords 
    attacks = if pt == PAWN
        pawn_attacks(from_sq, color)
    elseif pt == LANCE
        lance_attacks(from_sq, occ, color)
    elseif pt == KNIGHT
        knight_attacks(from_sq, color)
    elseif pt == SILVER
        silver_attacks(from_sq, color)
    elseif pt == GOLD || moves_like_gold(pt)
        gold_attacks(from_sq, color)
    elseif pt == BISHOP
        bishop_attacks(from_sq, occ)
    elseif pt == ROOK
        rook_attacks(from_sq, occ)
    elseif pt == KING
        KING_ATTACKS[from_sq]
    elseif pt == PROMOTED_BISHOP
        horse_attacks(from_sq, occ)
    elseif pt == PROMOTED_ROOK
        dragon_attacks(from_sq, occ)
    else
        EMPTY_BB
    end

    return test_bit(attacks, to_sq)
end

# position validation
function validate_position(state::BoardState)::Tuple{Bool, Vector{String}}
    errors = String[]

    # each color can only have one king
    for color in (BLACK, WHITE)
        king_count = popcount(state.kings[Int(color)])
        if king_count == 0
            push!(errors, "$(color) has no king")
        elseif king_count > 1
            push!(errors, "$(color) has multiple kings")
        end
    end

    #check kings position matches
    for color in (BLACK, WHITE)
        king_bb = state.kings[Int(color)]
        if popcount(king_bb) == 1
            actual_sq = lsb(king_bb)
            if state.king_sq[Int(color)] != actual_sq
                push!(errors, "$(color) king positions mismatch")
            end
        end
    end

    # check no piece overlap 
    if (state.occupied_by[Int(BLACK)] & state.occupied_by[Int(WHITE)]) != EMPTY_BB
        push!(errors, "Black and white pieces overlap")
    end

    # check occupied bitboards are consistent
    computed_black = EMPTY_BB
    computed_white = EMPTY_BB

    for pt in [PAWN, LANCE, KNIGHT, SILVER, GOLD, BISHOP, ROOK, KING,
               PROMOTED_PAWN, PROMOTED_LANCE, PROMOTED_KNIGHT, PROMOTED_SILVER,
               PROMOTED_BISHOP, PROMOTED_ROOK]
        computed_black |= get_piece_bb(state, pt, BLACK)
        computed_white |= get_piece_bb(state, pt, WHITE)
    end
    
    if computed_black != state.occupied_by[Int(BLACK)]
        push!(errors, "Black occupied bitboard mismatch")
    end
    if computed_white != state.occupied_by[Int(WHITE)]
        push!(errors, "White occupied bitboard mismatch")
    end

    # check pice max amount 
    for pt in [PAWN, SILVER, GOLD, BISHOP, ROOK]
        black_count = popcount(get_piece_bb(state, pt, BLACK))
        white_count = popcount(get_piece_bb(state, pt, WHITE))
        black_hand = hand_count(state, pt, BLACK)
        white_hand = hand_count(state, pt, WHITE)
        
        total = black_count + white_count + black_hand + white_hand
        if total > 2
            push!(errors, "Too many $(pt)s in game: $total")
        end
    end

    # check nifu
    for color in (BLACK, WHITE)
        pawns = state.pawns[Int(color)]
        for file in 1:BOARD_SIZE
            file_pawns = pawns & FILE_BB[file]
            if popcount(file_pawns) > 1
                push!(errors, "$(color) has two pawns on file: $file")
            end
        end
    end

    # check pawns/lances/knights not on impossible ranks 
    for color in (BLACK, WHITE)
        last_rank = color == BLACK ? 1 : BOARD_SIZE
        last_two_ranks = color == BLACK ? (1, 2) : (BOARD_SIZE-1, BOARD_SIZE)
        
        # pawns cant be on last rank 
        pawns = state.pawns[Int(color)]
        if (pawns & RANK_BB[last_rank]) != EMPTY_BB
            push!(errors, "$(color) has unpromoted pawn on last rank")
        end
        
        # lances cant be on last rank 
        lances = state.lances[Int(color)]
        if (lances & RANK_BB[last_rank]) != EMPTY_BB
            push!(errors, "$(color) has unpromoted lance on last rank")
        end
        
        # knights can't be on last two ranks 
        knights = state.knights[Int(color)]
        for r in last_two_ranks
            if r >= 1 && r <= BOARD_SIZE && (knights & RANK_BB[r]) != EMPTY_BB
                push!(errors, "$(color) has unpromoted knight on rank $r")
            end
        end
    end

    # check hand pieces counts are non-negative
    for color in (BLACK, WHITE)
        for idx in 1:7
            if state.hand[Int(color)][idx] < 0
                pt = hand_index_to_piece(idx)
                push!(errors, "$(color) has negative $(pt) in hand")
            end
        end
    end

    is_valid = isempty(errors)
    return (is_valid, errors)
end

# get game result
function get_game_result(state::BoardState, side_to_move::Color)::GameStatus
    # check checkmate, check check check 
    if is_in_check(state, side_to_move)
        if isempty(generate_legal_moves(state, side_to_move))
            return side_to_move == BLACK ? WHITE_WINS_CHECKMATE : BLACK_WINS_CHECKMATE
        end
    end

    # check for stalemate (no legal moves but not in check)
    if isempty(generate_legal_moves(state, side_to_move))
        return DRAW_STALEMATE
    end

    return ONGOING
end

# move formatting output
function format_move(move::Move)::String
    from_sq = move_from(move)
    to_sq = move_to(move)
    pt = move_piece(move)
    is_promo = move_is_promotion(move)

    piece_char = get(PIECE_TYPE_TO_CHAR, pt, '?')
    
    if move_is_drop(move)
        return "$(piece_char)*$(square_to_string(to_sq))"
    else
        move_str = "$(square_to_string(from_sq))$(square_to_string(to_sq))"
        if is_promo
            move_str *= "+"
        end
        return move_str
    end
end

# extra info move output
function format_move_verbose(move::Move, state::BoardState)::String
    from_sq = move_from(move)
    to_sq = move_to(move)
    pt = move_piece(move)
    is_promo = move_is_promotion(move)
    captured = move_capture(move)
    
    piece_char = get(PIECE_TYPE_TO_CHAR, pt, '?')
    
    if move_is_drop(move)
        return "$(piece_char)*$(square_to_string(to_sq)) (drop)"
    else
        cap_str = captured != NO_PIECE ? "x$(PIECE_TYPE_TO_CHAR[PieceType(captured)])" : ""
        promo_str = is_promo ? "+" : ""
        return "$(piece_char)$(square_to_string(from_sq))-$(square_to_string(to_sq))$(cap_str)$(promo_str)"
    end
end

# user move
function try_make_move(notation::String, state::BoardState, color::Color)::Tuple{Union{Move, Nothing}, String}
    move = parse_move(notation, state, color)
    if move === nothing
        return (nothing, "Invalid move notation: '$notation'")
    end
    # validate move
    is_valid, reason = validate_move(state, move, color)
    if !is_valid 
        return (nothing, reason)
    end

    return (move, "OK")
end

# get all leagal moves as strings
function get_legal_move_strings(state::BoardState, color::Color)::Vector{String}
    moves = generate_legal_moves(state, color)
    return [format_move(m) for m in moves]
end

function test_validation()
    println("Testing validation...")
    
    if !MAGICS_INITIALIZED[]
        init_all_magics!()
    end
    
    state = initial_position()
    print_board(state)
    
    # Test position validation
    println("\n--- Position Validation ---")
    is_valid, errors = validate_position(state)
    println("Position valid: $is_valid")
    if !isempty(errors)
        for err in errors
            println("  Error: $err")
        end
    end
    
    # Test move parsing
    println("\n--- Move Parsing ---")
    test_notations = ["1d1c", "1d1c+", "P*3c", "invalid", "5e4d"]
    for notation in test_notations
        move = parse_move(notation, state, BLACK)
        if move === nothing
            println("  '$notation' → Parse failed")
        else
            println("  '$notation' → $(format_move(move))")
            valid, reason = validate_move(state, move, BLACK)
            println("    Valid: $valid ($reason)")
        end
    end
    
    # Test try_make_move
    println("\n--- Try Make Move ---")
    move, reason = try_make_move("1d1c", state, BLACK)
    if move !== nothing
        println("Move parsed and validated: $(format_move(move))")
        println("Applying move...")
        apply_move!(state, move, BLACK)
        print_board(state)
    else
        println("Move failed: $reason")
    end
    
    # Test game result
    println("\n--- Game Result ---")
    result = get_game_result(state, WHITE)
    println("Game result: $result")
    
    # Get legal moves as strings
    println("\n--- Legal Moves (as strings) ---")
    move_strings = get_legal_move_strings(state, WHITE)
    println("White's legal moves: $(length(move_strings))")
    for (i, ms) in enumerate(move_strings[1:min(10, length(move_strings))])
        println("  $i. $ms")
    end
    if length(move_strings) > 10
        println("  ... and $(length(move_strings) - 10) more")
    end
    
    println("\nValidation tests complete!")
end

# test_validation()