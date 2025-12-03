# server.jl

# julia --project=. server/server.jl

using HTTP
using JSON3

include("../src/BitShogi.jl")
using .BitShogi

function cors_headers()
    return [
        "Access-Control-Allow-Origin" => "*",
        "Access-Control-Allow-Methods" => "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers" => "Content-Type",
        "Content-Type" => "application/json"
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
        for (key, value) in cors_headers()
            HTTP.setheader(response, key => value)
        end
        return response
    end
end  

function handle_root(req::HTTP.Request)
    return HTTP.Response(200, JSON3.write(Dict(
        "message" => "BitShogi API",
        "status" => "running",
        "endpoints" => [
            "GET /api/game/new",
            "POST /api/game/move",
            "POST /api/game/bot-move",
            "GET /api/game/legal-moves"
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

# router 
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
    elseif path == "/api/game/move" && method == "POST"
        return handle_make_move(req)
    elseif path == "/api/game/bot-move" && method == "POST"
        return handle_bot_move(req)
    elseif startswith(path, "/api/game/legal-moves") && method == "GET"
        return handle_legal_moves(req)
    else
        return HTTP.Response(404, JSON3.write(Dict("error" => "Not found: $path")))
    end
end

# entry point 
function start_server(; host="0.0.0.0", port=8000)
    # Initialize engine
    println("Initializing BitShogi engine...")
    BitShogi.init_all_magics!()
    BitShogi.init_zobrist!()
    println("Engine ready!")
    
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
