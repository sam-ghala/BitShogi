using Test

# Include all source files directly
include("../src/constants.jl")
include("../src/types.jl")
include("../src/bitboard.jl")
include("../src/attack_tables.jl")
include("../src/magic.jl")
include("../src/board_state.jl")
include("../src/move_generation.jl")
include("../src/validation.jl")
include("../src/game_state.jl")

@testset "BitShogi.jl" begin
    include("constants_tests.jl")
    include("types_tests.jl")
    include("bitboard_tests.jl")
    include("magic_tests.jl")
    include("board_state_tests.jl")
    include("move_generation_tests.jl")
    include("validation_tests.jl")
    include("attack_tables_tests.jl")
    include("game_state_tests.jl")
end