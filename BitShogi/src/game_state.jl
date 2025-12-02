# full game management baby

# turn tracking
# move history
# move counter
# repetition
# SFEN import/export 

const ZOBRIST_PIECES = Array{UInt64}(undef, NUM_SQUARES, 14, 2)
const ZOBRIST_HAND = Array{UInt64}(undef, 7, 2, 3)
const ZOBRIST_SIDE = Ref{UInt64}(0)
const ZOBRIST_INITIALIZED = Ref(false)

# zobrist hashing creates a hash for each position 
function init_zobrist!()
    if ZOBRIST_INITIALIZED[]
        return
    end

    Random.seed!(42)
    # piece square combo 
    for sq in 1:NUM_SQUARES
        for pt in 1:14
            for c in 1:2
                ZOBRIST_PIECES[sq, pt, c] = rand(UInt64)
            end
        end
    end
    # hand pieces ( 2 max! now )
    for pt in 1:7
        for c in 1:2
            for count in 1:3
                ZOBRIST_HAND[pt, c, count] = rand(UInt64)
            end
        end
    end

    ZOBRIST_SIDE[] = rand(UInt64)
    ZOBRIST_INITIALIZED[] = true
end

# compute hash for a position
function compute_hash(board::BoardState, side_to_move::Color)::UInt64
    if !ZOBRIST_INITIALIZED[]
        init_zobrist!()
    end
    
    hash = UInt64(0)
    
    # hash al pices on board 
    for pt in instances(PieceType)
        for color in (BLACK, WHITE)
            bb = get_piece_bb(board, pt, color)
            for sq in squares(bb)
                hash ⊻= ZOBRIST_PIECES[sq, Int(pt), Int(color)]
            end
        end
    end
    
    # hash hand pieces 
    for color in (BLACK, WHITE)
        for idx in 1:7
            count = board.hand[Int(color)][idx]
            if count > 0
                # max 2 for hash 
                hash_count = min(count, 2)
                hash ⊻= ZOBRIST_HAND[idx, Int(color), hash_count]
            end
        end
    end
    
    # hash side to move
    if side_to_move == WHITE
        hash ⊻= ZOBRIST_SIDE[]
    end
    
    return hash
end

struct MoveRecord
    move::Move
    captured_piece::UInt8
    previous_hash::UInt64
end

mutable struct GameState
    board::BoardState # current board position
    side_to_move::Color # turn
    move_number::Int # full move counter
    ply::Int # half-move counter (total plies played)
    history::Vector{MoveRecord} # move history for undo
    position_hashes::Vector{UInt64} # all position hashes (for repetition)
    current_hash::UInt64 # current position hash
    result::GameStatus # current game result
end

function GameState()
    if !MAGICS_INITIALIZED[]
        init_all_magics!()
    end
    init_zobrist!()
    
    board = initial_position()
    side_to_move = BLACK
    move_number = 1
    ply = 0
    history = MoveRecord[]
    
    current_hash = compute_hash(board, side_to_move)
    position_hashes = [current_hash]
    
    result = ONGOING
    
    return GameState(board, side_to_move, move_number, ply, history, 
                     position_hashes, current_hash, result)
end

function GameState(board::BoardState, side_to_move::Color, move_number::Int = 1)
    if !MAGICS_INITIALIZED[]
        init_all_magics!()
    end
    init_zobrist!()
    
    ply = (move_number - 1) * 2 + (side_to_move == WHITE ? 1 : 0)
    history = MoveRecord[]
    
    current_hash = compute_hash(board, side_to_move)
    position_hashes = [current_hash]
    
    result = get_game_result(board, side_to_move)
    
    return GameState(board, side_to_move, move_number, ply, history,
                     position_hashes, current_hash, result)
end

function make_move!(game::GameState, move::Move)::Bool
    # validate move
    is_valid, reason = validate_move(game.board, move, game.side_to_move)
    if !is_valid
        return false
    end
    
    # record for history
    captured = move_capture(move)
    record = MoveRecord(move, captured, game.current_hash)
    push!(game.history, record)
    
    apply_move!(game.board, move, game.side_to_move)
    
    # turn update 
    game.side_to_move = opposite(game.side_to_move)
    game.ply += 1
    if game.side_to_move == BLACK
        game.move_number += 1
    end
    
    # hash
    game.current_hash = compute_hash(game.board, game.side_to_move)
    push!(game.position_hashes, game.current_hash)
    
    # has the game ended
    game.result = check_game_over(game)
    
    return true

end

function make_move!(game::GameState, notation::String)::Tuple{Bool, String}
    move, reason = try_make_move(notation, game.board, game.side_to_move)
    if move === nothing
        return (false, reason)
    end
    
    success = make_move!(game, move)
    return (success, success ? "OK" : "Move failed")
end

function undo_move!(game::GameState)::Bool
    if isempty(game.history)
        return false
    end
    
    record = pop!(game.history)
    move = record.move
    
    from_sq = move_from(move)
    to_sq = move_to(move)
    pt = move_piece(move)
    is_promo = move_is_promotion(move)
    captured = record.captured_piece
    
    # switch back to previous player
    game.side_to_move = opposite(game.side_to_move)
    game.ply -= 1
    if game.side_to_move == WHITE
        game.move_number -= 1
    end
    
    if move_is_drop(move)
        # undo drop: remove piece, add back to hand
        remove_piece!(game.board, to_sq, pt, game.side_to_move)
        add_to_hand!(game.board, pt, game.side_to_move)
    else
        # undo board move
        final_pt = is_promo ? promote(pt) : pt
        
        # remove piece from destination
        remove_piece!(game.board, to_sq, final_pt, game.side_to_move)
        
        # rut piece back at origin
        place_piece!(game.board, from_sq, pt, game.side_to_move)
        
        # restore captured piece if any
        if captured != NO_PIECE
            captured_pt = PieceType(captured)
            place_piece!(game.board, to_sq, captured_pt, opposite(game.side_to_move))
            # remove from hand (it was added when captured)
            remove_from_hand!(game.board, demote(captured_pt), game.side_to_move)
        end
    end
    
    # update occupied bitboards
    update_occupied!(game.board)
    
    # restore hash
    pop!(game.position_hashes)
    game.current_hash = record.previous_hash
    
    # reset result
    game.result = ONGOING
    
    return true
end

# GAME OVER 
function check_game_over(game::GameState)::GameStatus
    # check mate stale mate 
    result = get_game_result(game.board, game.side_to_move)
    if result != ONGOING
        return result
    end
    
    # check 4 fold reps for a draw 
    if count_repetitions(game) >= 4
        return DRAW_REPETITION
    end
    
    return ONGOING
end

function count_repetitions(game::GameState)::Int
    count = 0
    for hash in game.position_hashes
        if hash == game.current_hash
            count += 1
        end
    end
    return count
end

function is_game_over(game::GameState)::Bool
    return game.result != ONGOING
end

@inline current_player(game::GameState)::Color = game.side_to_move
@inline get_board(game::GameState)::BoardState = game.board
@inline get_move_number(game::GameState)::Int = game.move_number
@inline get_ply(game::GameState)::Int = game.ply
@inline get_result(game::GameState)::GameStatus = game.result

function get_legal_moves(game::GameState)::Vector{Move}
    return generate_legal_moves(game.board, game.side_to_move)
end

function is_in_check(game::GameState)::Bool
    return is_in_check(game.board, game.side_to_move)
end

function parse_sfen(sfen::String)::Union{GameState, Nothing}
    parts = split(strip(sfen))
    if length(parts) < 3
        return nothing
    end
    
    board_str = parts[1]
    side_str = parts[2]
    hand_str = parts[3]
    move_num = length(parts) >= 4 ? tryparse(Int, parts[4]) : 1
    if move_num === nothing
        move_num = 1
    end
    
    # side to move
    side_to_move = lowercase(side_str) == "b" ? BLACK : WHITE
    
    # parse board
    board = BoardState()
    ranks = split(board_str, '/')
    
    if length(ranks) != BOARD_SIZE
        return nothing
    end
    
    for (rank_idx, rank_str) in enumerate(ranks)
        file = 1
        i = 1
        while i <= length(rank_str) && file <= BOARD_SIZE
            c = rank_str[i]
            
            if isdigit(c)
                # empty  squares
                file += parse(Int, c)
                i += 1
            elseif c == '+'
                if i + 1 > length(rank_str)
                    return nothing
                end
                piece_char = rank_str[i + 1]
                if !haskey(SFEN_TO_PIECE, piece_char)
                    return nothing
                end
                base_pt, color = SFEN_TO_PIECE[piece_char]
                pt = promote(base_pt)
                sq = square_index(rank_idx, file)
                place_piece!(board, sq, pt, color)
                file += 1
                i += 2
            elseif haskey(SFEN_TO_PIECE, c)
                pt, color = SFEN_TO_PIECE[c]
                sq = square_index(rank_idx, file)
                place_piece!(board, sq, pt, color)
                file += 1
                i += 1
            else
                return nothing
            end
        end
    end
    
    # parse hand
    if hand_str != "-"
        i = 1
        while i <= length(hand_str)
            count = 1
            
            # check for count prefix
            if i <= length(hand_str) && isdigit(hand_str[i])
                count = parse(Int, hand_str[i])
                i += 1
            end
            
            if i > length(hand_str)
                break
            end
            
            piece_char = hand_str[i]
            if !haskey(SFEN_TO_PIECE, piece_char)
                i += 1
                continue
            end
            
            pt, color = SFEN_TO_PIECE[piece_char]
            for _ in 1:count
                add_to_hand!(board, pt, color)
            end
            i += 1
        end
    end
    
    update_occupied!(board)
    
    return GameState(board, side_to_move, move_num)
end

function to_sfen(game::GameState)::String
    board = game.board
    
    # board string
    board_parts = String[]
    for rank in 1:BOARD_SIZE
        rank_str = ""
        empty_count = 0
        
        for file in 1:BOARD_SIZE
            sq = square_index(rank, file)
            piece_info = piece_at(board, sq)
            
            if piece_info === nothing
                empty_count += 1
            else
                if empty_count > 0
                    rank_str *= string(empty_count)
                    empty_count = 0
                end
                pt, color = piece_info
                rank_str *= get(PIECE_TO_SFEN, (pt, color), "?")
            end
        end
        
        if empty_count > 0
            rank_str *= string(empty_count)
        end
        
        push!(board_parts, rank_str)
    end
    board_str = join(board_parts, "/")
    
    # side to move
    side_str = game.side_to_move == BLACK ? "b" : "w"
    
    # hand pieces
    hand_str = ""
    for color in (BLACK, WHITE)
        for idx in 1:7
            count = board.hand[Int(color)][idx]
            if count > 0
                pt = hand_index_to_piece(idx)
                piece_char = get(PIECE_TO_SFEN, (pt, color), "?")
                if count > 1
                    hand_str *= string(count)
                end
                hand_str *= piece_char
            end
        end
    end
    if isempty(hand_str)
        hand_str = "-"
    end
    
    # whicch move number
    move_str = string(game.move_number)
    
    return "$board_str $side_str $hand_str $move_str"
end

# display the game

function print_game(game::GameState)
    print_board(game.board)
    println("Side to move: $(game.side_to_move)")
    println("Move number: $(game.move_number)")
    println("Ply: $(game.ply)")
    println("Result: $(game.result)")
    println("SFEN: $(to_sfen(game))")
    
    if is_in_check(game)
        println("*** $(game.side_to_move) is in CHECK! ***")
    end
end

function print_move_history(game::GameState)
    println("Move history ($(length(game.history)) moves):")
    for (i, record) in enumerate(game.history)
        move_str = format_move(record.move)
        cap_str = record.captured_piece != NO_PIECE ? " (captured)" : ""
        println("  $i. $move_str$cap_str")
    end
end

function Base.copy(game::GameState)::GameState
    return GameState(
        copy(game.board),
        game.side_to_move,
        game.move_number,
        game.ply,
        copy(game.history),
        copy(game.position_hashes),
        game.current_hash,
        game.result
    )
end

function test_game_state()
    println("Testing GameState...")
    
    game = GameState()
    print_game(game)
    
    println("\n--- Legal Moves ---")
    moves = get_legal_moves(game)
    println("$(length(moves)) legal moves available")
    
    println("\n--- Making Moves ---")
    test_moves = ["1d1c", "5b5c", "4e4d"]
    
    for notation in test_moves
        println("\nAttempting: $notation")
        success, reason = make_move!(game, notation)
        if success
            println("  Move successful!")
            print_game(game)
        else
            println("  Move failed: $reason")
        end
        
        if is_game_over(game)
            println("  GAME OVER: $(game.result)")
            break
        end
    end
    
    println("\n--- Testing Undo ---")
    if !isempty(game.history)
        println("Undoing last move...")
        undo_move!(game)
        print_game(game)
    end
    
    println("\n--- Testing SFEN ---")
    sfen = to_sfen(game)
    println("Current SFEN: $sfen")
    
    println("\nParsing SFEN back...")
    parsed_game = parse_sfen(sfen)
    if parsed_game !== nothing
        println("Parsed successfully!")
        print_game(parsed_game)
    else
        println("Parse failed!")
    end
    
    println("\n--- Testing Initial SFEN ---")
    initial_sfen = "rbsgk/4p/5/P4/KGSBR b - 1"
    println("Parsing: $initial_sfen")
    game2 = parse_sfen(initial_sfen)
    if game2 !== nothing
        print_game(game2)
    end
    
    println("\n--- Move History ---")
    print_move_history(game)
    
    println("\nGameState tests complete!")
end

test_game_state()