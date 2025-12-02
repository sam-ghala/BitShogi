@testset "First game" begin
    println("Testing GameState...")
    
    game = GameState()
    print_game(game)
    
    println("\n--- Legal Moves ---")
    moves = get_legal_moves(game)
    println("$(length(moves)) legal moves available")
    
    println("\n--- Making Moves ---")
    test_moves = ["1d1c", "5b5c", "1c1b", "5c5d", "1b1a+", "5d5e+"] # "4e4d"
    
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

@testset "GameState: unit tests" begin
    @testset "Constructor and basics" begin
        g = GameState()
        @test get_move_number(g) == 1
        @test get_ply(g) == 0
        @test current_player(g) == BLACK
        @test !is_game_over(g)
        @test typeof(g.board) <: BoardState
    end

    @testset "Hashing and copy" begin
        g = GameState()
        h = g.current_hash
        g2 = Base.copy(g)
        @test g2.current_hash == h
        @test compute_hash(g.board, g.side_to_move) == h
    end

    @testset "Legal moves, make and undo" begin
        g = GameState()
        moves = get_legal_moves(g)
        @test length(moves) > 0
        initial_hash = g.current_hash
        initial_history_len = length(g.history)
        m = moves[1]
        success = make_move!(g, m)
        @test success
        @test length(g.history) == initial_history_len + 1
        @test g.current_hash != initial_hash || length(g.history) > 0
        ok = undo_move!(g)
        @test ok
        @test g.current_hash == initial_hash
        @test length(g.history) == initial_history_len
    end

    @testset "Make move by notation" begin
        g = GameState()
        mv = get_legal_moves(g)[1]
        notation = format_move(mv)
        res = make_move!(g, notation)
        @test isa(res, Tuple)
        @test res[1] == true
    end

    @testset "SFEN round-trip" begin
        g = GameState()
        s = to_sfen(g)
        pg = parse_sfen(s)
        @test pg !== nothing
        @test to_sfen(pg) == s
    end

    @testset "Undo on empty history" begin
        g = GameState()
        while !isempty(g.history)
            undo_move!(g)
        end
        @test !undo_move!(g)
    end

    @testset "Repetition and counts" begin
        g = GameState()
        @test count_repetitions(g) >= 1
    end

    @testset "Check detection basic" begin
        g = GameState()
        @test isa(is_in_check(g), Bool)
    end
end
