# api, json web server integration

using JSON3

function api_new_game()::Dict{String, Any}
    game = GameState()
    return Dict{String, Any}(
        "sfen" => to_sfen(game),
        "side_to_move" => string(game.side_to_move),
        "legal_moves" => get_legal_move_strings(game.board, game.side_to_move),
        "is_check" => is_in_check(game),
        "result" => string(game.result),
        "hand" => get_hand_info(game.board)
    )
end

function api_load_position(sfen::String)::Dict{String, Any}
    game = parse_sfen(sfen)
    if game === nothing
        return Dict{String, Any}("error" => "Invalid SFEN", "success" => false)
    end
    
    return Dict{String, Any}(
        "success" => true,
        "sfen" => to_sfen(game),
        "side_to_move" => string(game.side_to_move),
        "legal_moves" => get_legal_move_strings(game.board, game.side_to_move),
        "is_check" => is_in_check(game),
        "result" => string(game.result),
        "hand" => get_hand_info(game.board),
        "bitboard" => sfen_to_bitboard(to_sfen(game))
    )
end

function api_make_move(sfen::String, move_notation::String)::Dict{String, Any}
    game = parse_sfen(sfen)
    if game === nothing
        return Dict{String, Any}("error" => "Invalid SFEN", "success" => false)
    end
    
    success, reason = make_move!(game, move_notation)
    if !success
        return Dict{String, Any}("error" => reason, "success" => false)
    end
    
    return Dict{String, Any}(
        "success" => true,
        "sfen" => to_sfen(game),
        "side_to_move" => string(game.side_to_move),
        "legal_moves" => get_legal_move_strings(game.board, game.side_to_move),
        "is_check" => is_in_check(game),
        "result" => string(game.result),
        "hand" => get_hand_info(game.board),
        "move_played" => move_notation
    )
end
function api_get_bot_move(sfen::String, bot_type::String = "minimax")::Dict{String, Any}
    game = parse_sfen(sfen)
    if game === nothing
        return Dict{String, Any}("error" => "Invalid SFEN", "success" => false)
    end
    
    bot = if bot_type == "random"
        RandomBot()
    elseif bot_type == "greedy"
        GreedyBot()
    elseif bot_type == "easy_minimax"
        MinimaxBot(3)
    elseif bot_type == "minimax"
        MinimaxBot(5)  # depth 5
    else
        GreedyBot()
    end
    
    move = select_move(bot, game)
    if move === nothing
        return Dict{String, Any}("error" => "No legal moves", "success" => false)
    end
    
    return Dict{String, Any}(
        "success" => true,
        "move" => format_move(move)
    )
end

function api_get_legal_moves(sfen::String)::Dict{String, Any}
    game = parse_sfen(sfen)
    if game === nothing
        return Dict{String, Any}("error" => "Invalid SFEN", "moves" => String[])
    end
    
    return Dict{String, Any}(
        "moves" => get_legal_move_strings(game.board, game.side_to_move),
        "count" => length(get_legal_moves(game))
    )
end

"""
    api_daily_puzzle() -> Dict{String, Any}

Get today's daily puzzle - a deterministic random position based on the date.
"""
function api_daily_puzzle()::Dict{String, Any}
    sfen, bitboard_int = generate_today_puzzle()
    state = parse_sfen(sfen)
    
    if state === nothing
        # Fallback to standard position
        state = GameState()
        sfen = to_sfen(state)
        bitboard_int = UInt32(32539167)  # Standard position bitboard
    end
    
    return Dict{String, Any}(
        "sfen" => sfen,
        "side_to_move" => string(state.side_to_move),
        "legal_moves" => get_legal_move_strings(state.board, state.side_to_move),
        "is_check" => is_in_check(state),
        "result" => string(state.result),
        "hand" => get_hand_info(state.board),
        "bitboard_int" => bitboard_int,
        "date" => string(Dates.today())
    )
end

"""
    api_daily_puzzle_for_date(date_str::String) -> Dict{String, Any}

Get the daily puzzle for a specific date (format: "YYYY-MM-DD").
"""
function api_daily_puzzle_for_date(date_str::String)::Dict{String, Any}
    try
        date = Date(date_str)
        sfen, bitboard_int = generate_daily_puzzle(date)
        state = parse_sfen(sfen)
        
        if state === nothing
            return Dict{String, Any}("error" => "Failed to generate puzzle", "success" => false)
        end
        
        return Dict{String, Any}(
            "sfen" => sfen,
            "side_to_move" => string(state.side_to_move),
            "legal_moves" => get_legal_move_strings(state.board, state.side_to_move),
            "is_check" => is_in_check(state),
            "result" => string(state.result),
            "hand" => get_hand_info(state.board),
            "bitboard_int" => bitboard_int,
            "date" => date_str
        )
    catch e
        return Dict{String, Any}("error" => "Invalid date format. Use YYYY-MM-DD", "success" => false)
    end
end

# Get hand pieces info for both players
function get_hand_info(board::BoardState)::Dict{String, Any}
    piece_names = ["PAWN", "LANCE", "KNIGHT", "SILVER", "GOLD", "BISHOP", "ROOK"]
    
    black_hand = Dict{String, Int}()
    white_hand = Dict{String, Int}()
    
    for (idx, name) in enumerate(piece_names)
        black_count = board.hand[Int(BLACK)][idx]
        white_count = board.hand[Int(WHITE)][idx]
        
        if black_count > 0
            black_hand[name] = black_count
        end
        if white_count > 0
            white_hand[name] = white_count
        end
    end
    
    return Dict{String, Any}(
        "BLACK" => black_hand,
        "WHITE" => white_hand
    )
end

# cli server 

function handle_json_request(request_json::String)::String
    try
        request = JSON3.read(request_json)
        action = get(request, :action, "")
        
        result = if action == "new_game"
            api_new_game()
        elseif action == "make_move"
            api_make_move(string(request[:sfen]), string(request[:move]))
        elseif action == "get_bot_move"
            bot_type = string(get(request, :bot_type, "greedy"))
            api_get_bot_move(string(request[:sfen]), bot_type)
        elseif action == "legal_moves"
            api_get_legal_moves(string(request[:sfen]))
        else
            Dict{String, Any}("error" => "Unknown action: $action")
        end
        
        return JSON3.write(result)
    catch e
        return JSON3.write(Dict{String, Any}("error" => string(e)))
    end
end

function run_cli_server()
    # Initialize engine
    if !MAGICS_INITIALIZED[]
        init_all_magics!()
    end
    init_zobrist!()
    
    println("BitShogi API ready")
    flush(stdout)
    
    while true
        line = readline()
        if isempty(line) || line == "quit"
            break
        end
        
        response = handle_json_request(line)
        println(response)
        flush(stdout)
    end
end