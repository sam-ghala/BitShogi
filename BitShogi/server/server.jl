# ===========================================================================
# server.jl - HTTP server for BitShogi
# ===========================================================================
# 
# Run with: julia --project=. server/server.jl
#
# ===========================================================================

using HTTP
using JSON3

# Include the engine
include("../src/BitShogi.jl")
using .BitShogi

# Anthropic API key from environment

const ANTHROPIC_API_KEY = get(ENV, "ANTHROPIC_API_KEY", "")

# ---------------------------------------------------------------------------
# CORS Middleware
# ---------------------------------------------------------------------------

function cors_headers()
    return [
        "Access-Control-Allow-Origin" => "*",
        "Access-Control-Allow-Methods" => "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers" => "Content-Type",
        "Content-Type" => "application/json"
    ]
end

function sse_headers()
    return [
        "Access-Control-Allow-Origin" => "*",
        "Content-Type" => "text/event-stream",
        "Cache-Control" => "no-cache",
        "Connection" => "keep-alive"
    ]
end

function handle_cors(handler)
    return function(req::HTTP.Request)
        # Handle preflight OPTIONS request
        if req.method == "OPTIONS"
            return HTTP.Response(200, cors_headers())
        end
        
        # Call actual handler and add CORS headers
        response = handler(req)
        
        # Don't modify streaming responses
        if HTTP.header(response, "Content-Type") == "text/event-stream"
            return response
        end
        
        for (key, value) in cors_headers()
            HTTP.setheader(response, key => value)
        end
        return response
    end
end

# ---------------------------------------------------------------------------
# Route Handlers
# ---------------------------------------------------------------------------

function handle_root(req::HTTP.Request)
    return HTTP.Response(200, JSON3.write(Dict(
        "message" => "BitShogi API",
        "status" => "running",
        "endpoints" => [
            "GET /api/game/new",
            "POST /api/game/move",
            "POST /api/game/bot-move",
            "POST /api/game/claude-move",
            "GET /api/game/legal-moves",
            "GET /api/game/daily",
            "GET /api/game/daily?date=YYYY-MM-DD"
        ]
    )))
end

function handle_new_game(req::HTTP.Request)
    result = BitShogi.api_new_game()
    return HTTP.Response(200, JSON3.write(result))
end

function handle_make_move(req::HTTP.Request)
    try
        body = JSON3.read(String(req.body))
        sfen = string(body[:sfen])
        move = string(body[:move])
        
        result = BitShogi.api_make_move(sfen, move)
        
        if !get(result, "success", false)
            return HTTP.Response(400, JSON3.write(result))
        end
        
        return HTTP.Response(200, JSON3.write(result))
    catch e
        return HTTP.Response(400, JSON3.write(Dict("error" => string(e), "success" => false)))
    end
end

function handle_bot_move(req::HTTP.Request)
    try
        body = JSON3.read(String(req.body))
        sfen = string(body[:sfen])
        bot_type = string(get(body, :bot_type, "greedy"))
        
        result = BitShogi.api_get_bot_move(sfen, bot_type)
        
        if !get(result, "success", false)
            return HTTP.Response(400, JSON3.write(result))
        end
        
        return HTTP.Response(200, JSON3.write(result))
    catch e
        return HTTP.Response(400, JSON3.write(Dict("error" => string(e), "success" => false)))
    end
end

function handle_legal_moves(req::HTTP.Request)
    try
        # Parse query parameters
        uri = HTTP.URI(req.target)
        params = HTTP.queryparams(uri)
        sfen = get(params, "sfen", "")
        
        if isempty(sfen)
            return HTTP.Response(400, JSON3.write(Dict("error" => "Missing sfen parameter")))
        end
        
        result = BitShogi.api_get_legal_moves(sfen)
        return HTTP.Response(200, JSON3.write(result))
    catch e
        return HTTP.Response(400, JSON3.write(Dict("error" => string(e))))
    end
end

function handle_daily_puzzle(req::HTTP.Request)
    try
        # Check if a specific date was requested
        uri = HTTP.URI(req.target)
        params = HTTP.queryparams(uri)
        date_str = get(params, "date", "")
        
        result = if isempty(date_str)
            BitShogi.api_daily_puzzle()
        else
            BitShogi.api_daily_puzzle_for_date(date_str)
        end
        
        return HTTP.Response(200, JSON3.write(result))
    catch e
        return HTTP.Response(400, JSON3.write(Dict("error" => string(e))))
    end
end

function handle_load_position(req::HTTP.Request)
    try
        body = JSON3.read(String(req.body))
        sfen = string(body[:sfen])
        
        result = BitShogi.api_load_position(sfen)
        
        if !get(result, "success", false)
            return HTTP.Response(400, JSON3.write(result))
        end
        
        return HTTP.Response(200, JSON3.write(result))
    catch e
        return HTTP.Response(400, JSON3.write(Dict("error" => string(e), "success" => false)))
    end
end

# ---------------------------------------------------------------------------
# Claude Streaming Handler
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Claude Handler (non-streaming for HTTP.jl compatibility)
# ---------------------------------------------------------------------------

function handle_claude_move(req::HTTP.Request)
    if isempty(ANTHROPIC_API_KEY)
        return HTTP.Response(500, JSON3.write(Dict(
            "error" => "Anthropic API key not configured",
            "success" => false
        )))
    end
    
    try
        body = JSON3.read(String(req.body))
        sfen = string(body[:sfen])
        
        # Parse game state
        game = BitShogi.parse_sfen(sfen)
        if game === nothing
            return HTTP.Response(400, JSON3.write(Dict(
                "error" => "Invalid SFEN",
                "success" => false
            )))
        end
        
        legal_moves = BitShogi.get_legal_move_strings(game.board, game.side_to_move)
        if isempty(legal_moves)
            return HTTP.Response(400, JSON3.write(Dict(
                "error" => "No legal moves",
                "success" => false
            )))
        end
        
        # Build prompt for Claude
        prompt = """You are playing minishogi (5x5 Japanese chess).

        CRITICAL - PIECE IDENTIFICATION:
        - YOUR pieces are LOWERCASE: k, g, s, r, b, p
        - OPPONENT pieces are UPPERCASE: K, G, S, R, B, P
        - If you see an UPPERCASE letter, that is the ENEMY piece, not yours!
        - UPPERCASE pieces are ENEMY pieces you can capture!
        - If you see a lowercase letter, that is YOUR piece.

        Current position (SFEN): $sfen

        Your legal moves: $(join(legal_moves, ", "))

        Move notation:
        - Board moves: "1a2b" = move piece FROM 1a TO 2b
        - Promotions: "1a2b+" = move and promote
        - Drops: "p*3c" = drop a pawn from your hand onto 3c

        SFEN board explanation:
        - Format: <board>/<board>/... <turn> <hands> <move#>
        - Ranks go a (top) to e (bottom), files go 1 (left) to 5 (right)
        - "w" = your turn, "b" = opponent's turn
        - In the hand section: lowercase = YOUR hand, UPPERCASE = opponent's hand

        First, identify where YOUR pieces (lowercase) are located.
        Then identify where OPPONENT pieces (UPPERCASE) are located.
        Look for captures, checks, and threats.

        Explain your thinking briefly (2-3 paragraphs), then choose your move.
        End with exactly: MOVE: <your chosen move>"""

        # Call Anthropic API (non-streaming)
        response = HTTP.request(
            "POST",
            "https://api.anthropic.com/v1/messages",
            [
                "Content-Type" => "application/json",
                "x-api-key" => ANTHROPIC_API_KEY,
                "anthropic-version" => "2023-06-01"
            ],
            JSON3.write(Dict(
                "model" => "claude-haiku-4-5",
                "max_tokens" => 1024,
                "messages" => [
                    Dict("role" => "user", "content" => prompt)
                ]
            ))
        )
        
        result = JSON3.read(String(response.body))
        
        # Extract text from response
        reasoning = ""
        if haskey(result, :content) && length(result.content) > 0
            reasoning = string(result.content[1].text)
        end
        
        # Extract move from response
        move_match = match(r"MOVE:\s*([A-Za-z0-9\+\*]+)"i, reasoning)
        
        chosen_move = if move_match !== nothing
            strip(move_match.captures[1])
        else
            legal_moves[1]  # fallback
        end
        
        # Validate move is legal (case-insensitive match)
        if !(chosen_move in legal_moves)
            matched_idx = findfirst(m -> lowercase(m) == lowercase(chosen_move), legal_moves)
            if matched_idx !== nothing
                chosen_move = legal_moves[matched_idx]
            else
                chosen_move = legal_moves[1]  # fallback to first legal move
            end
        end
        
        return HTTP.Response(200, JSON3.write(Dict(
            "success" => true,
            "move" => chosen_move,
            "reasoning" => reasoning
        )))
        
    catch e
        return HTTP.Response(400, JSON3.write(Dict(
            "error" => string(e),
            "success" => false
        )))
    end
end

# ---------------------------------------------------------------------------
# Router
# ---------------------------------------------------------------------------

function router(req::HTTP.Request)
    # Parse path
    uri = HTTP.URI(req.target)
    path = uri.path
    method = req.method
    
    # Route matching
    if path == "/" || path == ""
        return handle_root(req)
    elseif path == "/api/game/new" && method == "GET"
        return handle_new_game(req)
    elseif path == "/api/game/load" && method == "POST"
        return handle_load_position(req)
    elseif path == "/api/game/move" && method == "POST"
        return handle_make_move(req)
    elseif path == "/api/game/bot-move" && method == "POST"
        return handle_bot_move(req)
    elseif path == "/api/game/claude-move" && method == "POST"
        return handle_claude_move(req)
    elseif startswith(path, "/api/game/legal-moves") && method == "GET"
        return handle_legal_moves(req)
    elseif startswith(path, "/api/game/daily") && method == "GET"
        return handle_daily_puzzle(req)
    else
        return HTTP.Response(404, JSON3.write(Dict("error" => "Not found: $path")))
    end
end

# ---------------------------------------------------------------------------
# Server Entry Point
# ---------------------------------------------------------------------------

function start_server(; host="0.0.0.0", port=8000)
    # Initialize engine
    println("Initializing BitShogi engine...")
    BitShogi.init_all_magics!()
    BitShogi.init_zobrist!()
    println("Engine ready!")
    
    # Check for API key
    if isempty(ANTHROPIC_API_KEY)
        println("⚠️  Warning: ANTHROPIC_API_KEY not set - Claude bot will not work")
    else
        println("✓ Anthropic API key configured")
    end
    
    println("\n" * "="^50)
    println("BitShogi Server")
    println("="^50)
    println("Listening on http://$host:$port")
    println("Press Ctrl+C to stop")
    println("="^50 * "\n")
    
    # Start server with CORS middleware
    HTTP.serve(handle_cors(router), host, port)
end

# Run if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    start_server()
end