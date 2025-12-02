# board_state.jl, construct bitboards for all pieces, move generation, evaluation, pieces in hand, affrefate bitboards, king poisitons

mutable struct BoardState 
    # piece bitboards one per color
    # black = 1, white = 2

    pawns::Vector{Bitboard}
    lances::Vector{Bitboard}
    knights::Vector{Bitboard}
    silvers::Vector{Bitboard}
    golds::Vector{Bitboard}
    bishops::Vector{Bitboard}
    rooks::Vector{Bitboard}
    kings::Vector{Bitboard}
    # promoted pieces
    promoted_pawns::Vector{Bitboard}
    promoted_lances::Vector{Bitboard}
    promoted_knights::Vector{Bitboard}
    promoted_silvers::Vector{Bitboard}
    promoted_bishops::Vector{Bitboard}
    promoted_rooks::Vector{Bitboard}

    occupied_by::Vector{Bitboard} # per color
    occupied::Bitboard # all pieces 

    # kind position
    king_sq::Vector{Int}

    # pieces in hand avialable for drop play 
    hand::Vector{Vector{Int}} # [black, white][piece type] = count
end

function BoardState()
    # init board state for each type of piece 
    pawns = [EMPTY_BB, EMPTY_BB]
    lances = [EMPTY_BB, EMPTY_BB]
    knights = [EMPTY_BB, EMPTY_BB]
    silvers = [EMPTY_BB, EMPTY_BB]
    golds = [EMPTY_BB, EMPTY_BB]
    bishops = [EMPTY_BB, EMPTY_BB]
    rooks = [EMPTY_BB, EMPTY_BB]
    kings = [EMPTY_BB, EMPTY_BB]
    
    promoted_pawns = [EMPTY_BB, EMPTY_BB]
    promoted_lances = [EMPTY_BB, EMPTY_BB]
    promoted_knights = [EMPTY_BB, EMPTY_BB]
    promoted_silvers = [EMPTY_BB, EMPTY_BB]
    promoted_bishops = [EMPTY_BB, EMPTY_BB]
    promoted_rooks = [EMPTY_BB, EMPTY_BB]
    
    occupied_by = [EMPTY_BB, EMPTY_BB]
    occupied = EMPTY_BB

    king_sq = [0,0]

    hand = [zeros(Int, 7), zeros(Int, 7)]

    return BoardState(
        pawns, lances, knights, silvers, golds, bishops, rooks, kings,
        promoted_pawns, promoted_lances, promoted_knights, promoted_silvers,
        promoted_bishops, promoted_rooks,
        occupied_by, occupied, king_sq, hand
    )
end

# get specific piece bitboards
function get_piece_bb(state::BoardState, pt::PieceType, color::Color)::Bitboard
    c = Int(color)
    
    if pt == PAWN
        return state.pawns[c]
    elseif pt == LANCE
        return state.lances[c]
    elseif pt == KNIGHT
        return state.knights[c]
    elseif pt == SILVER
        return state.silvers[c]
    elseif pt == GOLD
        return state.golds[c]
    elseif pt == BISHOP
        return state.bishops[c]
    elseif pt == ROOK
        return state.rooks[c]
    elseif pt == KING
        return state.kings[c]
    elseif pt == PROMOTED_PAWN
        return state.promoted_pawns[c]
    elseif pt == PROMOTED_LANCE
        return state.promoted_lances[c]
    elseif pt == PROMOTED_KNIGHT
        return state.promoted_knights[c]
    elseif pt == PROMOTED_SILVER
        return state.promoted_silvers[c]
    elseif pt == PROMOTED_BISHOP
        return state.promoted_bishops[c]
    elseif pt == PROMOTED_ROOK
        return state.promoted_rooks[c]
    else
        return EMPTY_BB
    end
end
# set specific piece bitboards
function set_piece_bb!(state::BoardState, pt::PieceType, color::Color, bb::Bitboard)
    c = Int(color)

    if pt == PAWN
        state.pawns[c] = bb
    elseif pt == LANCE
        state.lances[c] = bb
    elseif pt == KNIGHT
        state.knights[c] = bb
    elseif pt == SILVER
        state.silvers[c] = bb
    elseif pt == GOLD
        state.golds[c] = bb
    elseif pt == BISHOP
        state.bishops[c] = bb
    elseif pt == ROOK
        state.rooks[c] = bb
    elseif pt == KING
        state.kings[c] = bb
    elseif pt == PROMOTED_PAWN
        state.promoted_pawns[c] = bb
    elseif pt == PROMOTED_LANCE
        state.promoted_lances[c] = bb
    elseif pt == PROMOTED_KNIGHT
        state.promoted_knights[c] = bb
    elseif pt == PROMOTED_SILVER
        state.promoted_silvers[c] = bb
    elseif pt == PROMOTED_BISHOP
        state.promoted_bishops[c] = bb
    elseif pt == PROMOTED_ROOK
        state.promoted_rooks[c] = bb
    end 
end

function place_piece!(state::BoardState, sq::Int, pt::PieceType, color::Color)
    bb = get_piece_bb(state, pt, color)
    bb = set_bit(bb ,sq)
    set_piece_bb!(state, pt, color, bb)

    if pt == KING
        state.king_sq[Int(color)] = sq
    end
end

function remove_piece!(state::BoardState, sq::Int, pt::PieceType, color::Color)
    bb = get_piece_bb(state, pt, color)
    bb = clear_bit(bb ,sq)
    set_piece_bb!(state, pt, color, bb)

    if pt == KING
        state.king_sq[Int(color)] = 0
    end
end

function move_piece!(state::BoardState, from_sq::Int, to_sq::Int, pt::PieceType, color::Color)
    bb = get_piece_bb(state, pt, color)
    bb = clear_bit(bb, from_sq)
    bb = set_bit(bb ,to_sq)
    set_piece_bb!(state, pt, color, bb)

    if pt == KING
        state.king_sq[Int(color)] = to_sq
    end
end

function update_occupied!(state::BoardState)
    # Black pieces
    state.occupied_by[Int(BLACK)] = 
        state.pawns[1] | state.lances[1] | state.knights[1] |
        state.silvers[1] | state.golds[1] | state.bishops[1] |
        state.rooks[1] | state.kings[1] |
        state.promoted_pawns[1] | state.promoted_lances[1] |
        state.promoted_knights[1] | state.promoted_silvers[1] |
        state.promoted_bishops[1] | state.promoted_rooks[1]
    
    # White pieces
    state.occupied_by[Int(WHITE)] = 
        state.pawns[2] | state.lances[2] | state.knights[2] |
        state.silvers[2] | state.golds[2] | state.bishops[2] |
        state.rooks[2] | state.kings[2] |
        state.promoted_pawns[2] | state.promoted_lances[2] |
        state.promoted_knights[2] | state.promoted_silvers[2] |
        state.promoted_bishops[2] | state.promoted_rooks[2]

    state.occupied = state.occupied_by[Int(BLACK)] | state.occupied_by[Int(WHITE)]
end

#all pieces of one color
@inline pieces(state::BoardState, color::Color)::Bitboard = state.occupied_by[Int(color)]
# all occupied squares bitboard
@inline occupied(state::BoardState)::Bitboard = state.occupied
# get empty squares 
@inline empty_squares(state::BoardState)::Bitboard = ~state.occupied & FULL_BB
# is square occupied by color
@inline is_occupied_by(state::BoardState, sq::Int, color::Color)::Bool = test_bit(state.occupied_by[Int(color)], sq)
# king square 
@inline king_square(state::BoardState, color::Color)::Bitboard = state.king_sq[Int(color)]

# what piece on given square
function piece_at(state::BoardState, sq::Int)::Union{Tuple{PieceType, Color}, Nothing}
    sq_bb = square_bb(sq)
    if (state.occupied & sq_bb) == EMPTY_BB
        return nothing 
    end

    color = (state.occupied_by[Int(BLACK)] & sq_bb) != EMPTY_BB ? BLACK : WHITE 
    c = Int(color)

    if (state.pawns[c] & sq_bb) != EMPTY_BB
        return (PAWN, color)
    elseif (state.lances[c] & sq_bb) != EMPTY_BB
        return (LANCE, color)
    elseif (state.knights[c] & sq_bb) != EMPTY_BB
        return (KNIGHT, color)
    elseif (state.silvers[c] & sq_bb) != EMPTY_BB
        return (SILVER, color)
    elseif (state.golds[c] & sq_bb) != EMPTY_BB
        return (GOLD, color)
    elseif (state.bishops[c] & sq_bb) != EMPTY_BB
        return (BISHOP, color)
    elseif (state.rooks[c] & sq_bb) != EMPTY_BB
        return (ROOK, color)
    elseif (state.kings[c] & sq_bb) != EMPTY_BB
        return (KING, color)
    elseif (state.promoted_pawns[c] & sq_bb) != EMPTY_BB
        return (PROMOTED_PAWN, color)
    elseif (state.promoted_lances[c] & sq_bb) != EMPTY_BB
        return (PROMOTED_LANCE, color)
    elseif (state.promoted_knights[c] & sq_bb) != EMPTY_BB
        return (PROMOTED_KNIGHT, color)
    elseif (state.promoted_silvers[c] & sq_bb) != EMPTY_BB
        return (PROMOTED_SILVER, color)
    elseif (state.promoted_bishops[c] & sq_bb) != EMPTY_BB
        return (PROMOTED_BISHOP, color)
    elseif (state.promoted_rooks[c] & sq_bb) != EMPTY_BB
        return (PROMOTED_ROOK, color)
    end
    
    return nothing
end

# convert piece type to hand vector index
function hand_index(pt::PieceType)::Int
    base_pt = demote(pt)

    if base_pt == PAWN
        return 1
    elseif base_pt == LANCE
        return 2
    elseif base_pt == KNIGHT
        return 3
    elseif base_pt == SILVER
        return 4
    elseif base_pt == GOLD
        return 5
    elseif base_pt == BISHOP
        return 6
    elseif base_pt == ROOK
        return 7
    else
        error("Invalid piece type for hand: $pt")
    end
end

# convert hand index to piece type
function hand_index_to_piece(idx::Int)::PieceType
    pieces = [PAWN, LANCE, KNIGHT, SILVER, GOLD, BISHOP, ROOK]
    return pieces[idx]
end

# add a piece to hand
function add_to_hand!(state::BoardState, pt::PieceType, color::Color)
    idx = hand_index(pt)
    state.hand[Int(color)][idx] += 1
end

# remove a piece from hand
function remove_from_hand!(state::BoardState, pt::PieceType, color::Color)
    idx = hand_index(pt)
    if state.hand[Int(color)][idx] <= 0
        error("No $pt in $(color)'s hand to remove")
    end
    state.hand[Int(color)][idx] -= 1
end

# get count of a piece type in hand
@inline function hand_count(state::BoardState, pt::PieceType, color::Color)::Int
    idx = hand_index(pt)
    return state.hand[Int(color)][idx]
end

# check if a player has a piece type in hand
@inline function has_in_hand(state::BoardState, pt::PieceType, color::Color)::Bool
    return hand_count(state, pt, color) > 0
end

# get all piece types in hand
function pieces_in_hand(state::BoardState, color::Color)::Vector{PieceType}
    result = PieceType[]
    for idx in 1:7
        if state.hand[Int(color)][idx] > 0
            push!(result, hand_index_to_piece(idx))
        end
    end
    return result
end

# copy board state
function Base.copy(state::BoardState)::BoardState
    return BoardState(
        copy(state.pawns), copy(state.lances), copy(state.knights),
        copy(state.silvers), copy(state.golds), copy(state.bishops),
        copy(state.rooks), copy(state.kings),
        copy(state.promoted_pawns), copy(state.promoted_lances),
        copy(state.promoted_knights), copy(state.promoted_silvers),
        copy(state.promoted_bishops), copy(state.promoted_rooks),
        copy(state.occupied_by), state.occupied,
        copy(state.king_sq),
        [copy(state.hand[1]), copy(state.hand[2])]
    )
end

function initial_position()::BoardState
    # Minishogi starting position:
    #       1   2   3   4   5
    #     +---+---+---+---+---+
    #  1  | r | b | s | g | k |    ← White's back rank
    #     +---+---+---+---+---+
    #  2  |   |   |   |   | p |    ← White's pawn
    #     +---+---+---+---+---+
    #  3  |   |   |   |   |   |    ← Empty
    #     +---+---+---+---+---+
    #  4  | P |   |   |   |   |    ← Black's pawn
    #     +---+---+---+---+---+
    #  5  | K | G | S | B | R |    ← Black's back rank
    #     +---+---+---+---+---+
    state = BoardState()
    # white pieces (rank 1)
    place_piece!(state, square_index(1, 1), ROOK, WHITE)
    place_piece!(state, square_index(1, 2), BISHOP, WHITE)
    place_piece!(state, square_index(1, 3), SILVER, WHITE)
    place_piece!(state, square_index(1, 4), GOLD, WHITE)
    place_piece!(state, square_index(1, 5), KING, WHITE)
    
    # white pawns (rank 2)
    place_piece!(state, square_index(2, 5), PAWN, WHITE)
    
    # black pawns (rank 4)
    place_piece!(state, square_index(4, 1), PAWN, BLACK)
    
    # black pieces (rank 5)
    place_piece!(state, square_index(5, 1), KING, BLACK)
    place_piece!(state, square_index(5, 2), GOLD, BLACK)
    place_piece!(state, square_index(5, 3), SILVER, BLACK)
    place_piece!(state, square_index(5, 4), BISHOP, BLACK)
    place_piece!(state, square_index(5, 5), ROOK, BLACK)
    
    update_occupied!(state)
    
    return state
end

function print_board(state::BoardState)
    piece_chars = Dict(
        (PAWN, BLACK) => "P", (LANCE, BLACK) => "L", (KNIGHT, BLACK) => "N",
        (SILVER, BLACK) => "S", (GOLD, BLACK) => "G", (BISHOP, BLACK) => "B",
        (ROOK, BLACK) => "R", (KING, BLACK) => "K",
        (PROMOTED_PAWN, BLACK) => "+P", (PROMOTED_LANCE, BLACK) => "+L",
        (PROMOTED_KNIGHT, BLACK) => "+N", (PROMOTED_SILVER, BLACK) => "+S",
        (PROMOTED_BISHOP, BLACK) => "+B", (PROMOTED_ROOK, BLACK) => "+R",
        
        (PAWN, WHITE) => "p", (LANCE, WHITE) => "l", (KNIGHT, WHITE) => "n",
        (SILVER, WHITE) => "s", (GOLD, WHITE) => "g", (BISHOP, WHITE) => "b",
        (ROOK, WHITE) => "r", (KING, WHITE) => "k",
        (PROMOTED_PAWN, WHITE) => "+p", (PROMOTED_LANCE, WHITE) => "+l",
        (PROMOTED_KNIGHT, WHITE) => "+n", (PROMOTED_SILVER, WHITE) => "+s",
        (PROMOTED_BISHOP, WHITE) => "+b", (PROMOTED_ROOK, WHITE) => "+r",
    )
    
    println("\n    " * join([" $f  " for f in 1:BOARD_SIZE]))
    println("   +" * repeat("---+", BOARD_SIZE))
    
    for r in 1:BOARD_SIZE
        print(" $r |")
        for f in 1:BOARD_SIZE
            sq = square_index(r, f)
            piece_info = piece_at(state, sq)
            
            if piece_info === nothing
                print("   |")
            else
                pt, color = piece_info
                char = get(piece_chars, (pt, color), "?")
                # Pad to 3 characters
                print(lpad(char, 2) * " |")
            end
        end
        println()
        println("   +" * repeat("---+", BOARD_SIZE))
    end
    
    # Print hand pieces
    println("\nHand pieces:")
    for color in (BLACK, WHITE)
        hand_str = "  $(color): "
        has_pieces = false
        for idx in 1:7
            count = state.hand[Int(color)][idx]
            if count > 0
                pt = hand_index_to_piece(idx)
                hand_str *= "$(pt)×$count "
                has_pieces = true
            end
        end
        if !has_pieces
            hand_str *= "(empty)"
        end
        println(hand_str)
    end
    println()
end

function validate_board(state::BoardState)::Bool
    all_valid = true

    computed_black = EMPTY_BB
    computed_white = EMPTY_BB

    for pt in [PAWN, LANCE, KNIGHT, SILVER, GOLD, BISHOP, ROOK, KING,
               PROMOTED_PAWN, PROMOTED_LANCE, PROMOTED_KNIGHT, PROMOTED_SILVER,
               PROMOTED_BISHOP, PROMOTED_ROOK]
        computed_black |= get_piece_bb(state, pt, BLACK)
        computed_white |= get_piece_bb(state, pt, WHITE)
    end

    if computed_black != state.occupied_by[Int(BLACK)]
        println("ERROR : Black occupied bitboard mismatch")
        all_valid = false
    end
    if computed_white != state.occupied_by[Int(WHITE)]
        println("ERROR : White occupied bitboard mismatch")
        all_valid = false
    end
    # check no overlap between colors
    if (state.occupied_by[Int(BLACK)]) & state.occupied_by[Int(WHITE)] != EMPTY_BB
        println("ERROR : Overlapping pieces")
        all_valid = false
    end

    for color in (BLACK, WHITE)
        king_bb = state.kings[Int(color)]
        if popcount(king_bb) == 1
            actual_sq = lsb(king_bb)
            if state.king_sq[Int(color)] != actual_sq
                println("ERROR : King pos cache mismatch for $color")
                all_valid = false
            end
        elseif popcount(king_bb) > 1
            println("Error : multiple kings for one color $color")
            all_valid = false
        end
    end
    return all_valid
end

function test_board_state()
    println("Testing BoardState...")
    
    if !MAGICS_INITIALIZED[]
        init_all_magics!()
    end
    
    state = initial_position()
    
    print_board(state)
    
    validate_board(state)
    
    println("\nTesting piece_at:")
    for sq in [1, 5, 13, 21, 25]
        result = piece_at(state, sq)
        if result === nothing
            println("  Square $sq: empty")
        else
            pt, color = result
            println("  Square $sq: $pt ($color)")
        end
    end
    
    # king pieces 
    println("\nKing positions:")
    println("  Black king: square $(king_square(state, BLACK))")
    println("  White king: square $(king_square(state, WHITE))")
    
    # hand pieces
    println("\nTesting hand pieces:")
    add_to_hand!(state, PAWN, BLACK)
    add_to_hand!(state, PAWN, BLACK)
    add_to_hand!(state, GOLD, BLACK)
    println("  Added two PAWN and GOLD to Black's hand")
    println("  Black has PAWN in hand: $(has_in_hand(state, PAWN, BLACK))")
    println("  Black's hand: $(pieces_in_hand(state, BLACK))")
    println("  Black's PAWN count: $(hand_count(state, PAWN, BLACK))")
    
    println("\nBoardState tests complete!")
end

test_board_state()