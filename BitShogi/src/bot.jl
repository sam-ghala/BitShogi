# simple bots for play testing
# random bot - picks random legal move
# greedy bot - captures when possible, then random
# minimax - minimax with ab pruning and ordered moves
# claude api - haiku model to see reasoning 

abstract type Bot end

function select_move(bot::Bot, game::GameState)::Union{Move, Nothing}
    error("implement select move for bot type: $(typeof(bot))")    
end
function bot_name(bot::Bot)::String
    return string(typeof(bot))    
end

# # # # # # # # # # # # # # # minimax bot # # # # # # # # # # # # # # 
struct MinimaxBot <: Bot
    depth::Int
end

MinimaxBot() = MinimaxBot(5)

bot_name(::MinimaxBot) = "MinimaxBot"

const PIECE_VALUES_BOT = Dict(
    PAWN => 100, LANCE => 300, KNIGHT => 300, SILVER => 400,
    GOLD => 500, BISHOP => 600, ROOK => 700, KING => 10000,
    PROMOTED_PAWN => 500, PROMOTED_LANCE => 500, PROMOTED_KNIGHT => 500,
    PROMOTED_SILVER => 500, PROMOTED_BISHOP => 800, PROMOTED_ROOK => 900
)

function evaluate_board(board::BoardState, color::Color)::Int
    score = 0
    # evaluate the board state and return our position value
    for pt in instances(PieceType)
        if pt == NO_PIECE
            continue
        end
        value = get(PIECE_VALUES_BOT, pt, 0)
        own = popcount(get_piece_bb(board, pt, color))
        opp = popcount(get_piece_bb(board, pt, opposite(color)))
        score += value * (own - opp)
    end

    # hand pieces are valuable 
    for idx in 1:7
        pt = hand_index_to_piece(idx)
        value = get(PIECE_VALUES_BOT, pt, 0)
        own_hand = board.hand[Int(color)][idx]
        opp_hand = board.hand[Int(opposite(color))][idx]
        score += Int(round(value * 1.1)) * (own_hand - opp_hand)
    end

    # control the inside space "I can't let you get close"
    center_sq = 13
    pc_at_center = piece_at(board, center_sq)
    if pc_at_center !== nothing
        pt, pc = pc_at_center
        if pc == color 
            score += 30
        else
            score -= 30
        end
    end
    return score
end

function order_moves(board::BoardState, moves::Vector{Move}, side::Color)::Vector{Move}
    scored = Tuple{Move, Int}[]

    for move in moves
        score = 0
        captured = move_capture(move)
        # score by piece value 
        if captured != NO_PIECE
            piece_value = get(PIECE_VALUES_BOT, PieceType(captured), 0)
            score += 10000 + piece_value
        end
        
        # promotions are good (not always though)
        if move_is_promotion(move)
            score += 5000
        end
        
        # drops to center is not that bad of a choice
        if move_is_drop(move)
            to_sq = move_to(move)
            if to_sq == 13 # center sq 
                score += 100
            end
        end
        push!(scored, (move, score))
    end

    # sort descending by score
    sort!(scored, by = x -> -x[2])
    return [m for (m, _) in scored]
end

function alphabeta(board::BoardState, depth::Int, α::Int, β::Int, maximizing::Bool, color::Color)::Int
    # case 0, game over, depth over
    if depth == 0
        return evaluate_board(board, color)
    end

    side = maximizing ? color : opposite(color)
    moves = generate_legal_moves(board, side)

    # no legal moves
    if isempty(moves)
        if is_in_check(board, side)
            # checkmate
            return maximizing ? -100000 + (10 - depth) : 100000 - (10 - depth)
        else
            # stalemate 
            return 0
        end
    end

    ordered_moves = order_moves(board, moves, side)

    if maximizing
        value = typemin(Int) + 1000
        for move in ordered_moves
            new_board = copy(board)
            apply_move!(new_board, move, side)
            value = max(value, alphabeta(new_board, depth - 1, α, β, false, color))
            α = max(α, value)
            if α >= β
                break  # β cutoff
            end
        end
        return value
    else
        value = typemax(Int) - 1000
        for move in ordered_moves
            new_board = copy(board)
            apply_move!(new_board, move, side)
            value = min(value, alphabeta(new_board, depth - 1, α, β, true, color))
            β = min(β, value)
            if α >= β
                break  # α cutoff
            end
        end
        return value
    end
end

function select_move(bot::MinimaxBot, game::GameState)::Union{Move, Nothing}
    moves = get_legal_moves(game)
    if isempty(moves)
        return nothing
    end

    color = game.side_to_move
    best_move = moves[1]
    best_value = typemin(Int) + 1000
    α = typemin(Int) + 1000
    β = typemax(Int) - 1000

    ordered_moves = order_moves(game.board, moves, color)

    for move in ordered_moves
        new_board = copy(game.board)
        apply_move!(new_board, move, color)
        # min opponents move
        value = alphabeta(new_board, bot.depth - 1, α, β, false, color)
        if value > best_value
            best_value = value
            best_move = move 
        end
        α = max(α, value)
    end
    return best_move
end

# # # # # # # # # # # # # # random bot # # # # # # # # # # # # # # 
struct RandomBot <: Bot
    rng::AbstractRNG
end

RandomBot() = RandomBot(Random.default_rng())
RandomBot(seed::Int) = RandomBot(MersenneTwister(seed))

function select_move(bot::RandomBot, game::GameState)::Union{Move, String}
    moves = get_legal_moves(game)
    if isempty(moves)
        return nothing
    end
    return moves[rand(bot.rng, 1:length(moves))]
end

bot_name(::RandomBot) = "RandomBot"

# # # # # # # # # # # # # # greedy bot # # # # # # # # # # # # # # 
struct GreedyBot <: Bot
    rng::AbstractRNG
end

GreedyBot() = GreedyBot(Random.default_rng())

function select_move(bot::GreedyBot, game::GameState)::Union{Move, String}
    moves = get_legal_moves(game)
    if isempty(moves)
        return nothing
    end
    captures = Tuple{Move, Int}[]
    non_captures = Move[]

    for move in moves 
        captured = move_capture(move)
        if captured != NO_PIECE
            value = get(PIECE_VALUES_BOT, PieceType(captured), 0)
            push!(captures, (move, value))
        else
            push!(non_captures, move)
        end
    end
    if !isempty(captures)
        # sort by value
        sort!(captures, by = x -> -x[2])
        return captures[1][1]
    end
    # pick random 
    return non_captures[rand(bot.rng, 1:length(non_captures))]
end

bot_name(::GreedyBot) = "GreedyBot"

# # # # # # # # # # # # # # simp bot # # # # # # # # # # # # # # 
# # # # # # # # # # # # # # decomissioned # # # # # # # # # # # # # # 
struct SimpleBot <: Bot
    depth::Int
end

SimpleBot() = SimpleBot(1)

function evaluate_position(board::BoardState, color::Color)::Int
    score = 0
    # material 
    for pt in instances(PieceType)
        value = get(PIECE_VALUES_BOT, pt, 0)
        
        own = popcount(get_piece_bb(board, pt, color))
        opp = popcount(get_piece_bb(board, pt, opposite(color)))
        
        score += value * (own - opp)
    end
    # high value for hand pieces 
    for idx in 1:7
        pt = hand_index_to_piece(idx)
        value = get(PIECE_VALUES_BOT, pt, 0)
        
        own_hand = board.hand[Int(color)][idx]
        opp_hand = board.hand[Int(opposite(color))][idx]
        
        score += Int(round(value * 1.1)) * (own_hand - opp_hand)
    end

    center_sq = 13  # (3,3) for 5x5 board
    if piece_at(board, center_sq) !== nothing
        pt, pc = piece_at(board, center_sq)
        if pc == color
            score += 20
        else
            score -= 20
        end
    end
    return score
end

bot_name(::SimpleBot) = "SimpleBot"

function select_move(bot::SimpleBot, game::GameState)::Union{Move, String}
    moves = get_legal_moves(game)
    if isempty(moves)
        return nothing
    end
    
    color = game.side_to_move
    best_move = moves[1]
    best_score = typemin(Int)
    
    for move in moves
        new_state = copy(game.board)
        apply_move!(new_state, move, color)
        
        # how is our position 
        score = evaluate_position(new_state, color)
        
        # bonus if in check 
        if is_in_check(new_state, opposite(color))
            score += 50
        end
        
        if score > best_score
            best_score = score
            best_move = move
        end
    end
    return best_move
end
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# # # # # # # # # # # # playing the game # # # # # # # # # # # # # # 
function play_bot_game(white_bot::Bot, black_bot::Bot; max_moves::Int = 200, verbose::Bool = true)
    game = GameState()
    
    if verbose
        println("Game: $(bot_name(black_bot)) (Black) vs $(bot_name(white_bot)) (White)")
        println("=" ^ 50)
        print_board(game.board)
    end
    
    while !is_game_over(game) && game.ply < max_moves
        bot = game.side_to_move == BLACK ? black_bot : white_bot
        
        move = select_move(bot, game)
        if move === nothing
            break
        end
        
        make_move!(game, move)
        
        if verbose
            println("\n$(game.side_to_move == BLACK ? "White" : "Black") plays: $(format_move(move))")
            print_board(game.board)
        end
    end
    
    if verbose
        println("\n" * "=" ^ 50)
        println("Game Over!")
        println("Result: $(game.result)")
        println("Moves played: $(game.ply)")
    end
    
    return game
end

# play within terminal
function play_vs_bot(bot::Bot; human_color::Color = BLACK)
    game = GameState()
    
    println("Playing vs $(bot_name(bot))")
    println("You are $(human_color)")
    println("Enter moves in USI format (e.g., '1d1c' or 'P*3c')")
    println("Type 'quit' to exit, 'undo' to take back")
    println()
    
    print_game(game)
    
    while !is_game_over(game)
        if game.side_to_move == human_color
            # Human turn
            print("\nYour move: ")
            input = readline()
            
            if lowercase(strip(input)) == "quit"
                println("Game abandoned.")
                break
            elseif lowercase(strip(input)) == "undo"
                # Undo both moves (human + bot)
                undo_move!(game)
                undo_move!(game)
                println("Undone!")
                print_game(game)
                continue
            elseif lowercase(strip(input)) == "moves"
                moves = get_legal_moves(game)
                println("Legal moves: $(join([format_move(m) for m in moves], ", "))")
                continue
            end
            
            success, reason = make_move!(game, input)
            if !success
                println("Invalid: $reason")
                continue
            end
        else
            # Bot turn
            println("\n$(bot_name(bot)) is thinking...")
            move = select_move(bot, game)
            if move === nothing
                println("Bot has no moves!")
                break
            end
            
            make_move!(game, move)
            println("$(bot_name(bot)) plays: $(format_move(move))")
        end
        
        print_game(game)
    end
    
    println("\nFinal result: $(game.result)")
    return game
end

# rando = RandomBot(42)
# play_vs_bot(rando)
# #             white bot    black bot 
# play_bot_game(RandomBot(1), RandomBot(42), max_moves=20, verbose=true)