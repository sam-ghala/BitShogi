module BitShogi

include("constants.jl")
include("types.jl")
include("bitboard.jl")
include("attack_tables.jl")
include("magic.jl")
include("board_state.jl")
include("move_generation.jl")
include("validation.jl")
include("game_state.jl")
include("perft.jl")
include("bot.jl")
include("api.jl")
include("board_generator.jl")

end

# Commands to run it locally after mpn install and installing julia packages 
# Terminal 1 - Backend
# cd ~/BitShogi/BitShogi && julia --project=. server/server.jl

# Terminal 2 - Frontend
# cd ~/BitShogi/BitShogi/frontend && npm run dev

# Browser
# http://localhost:5173
