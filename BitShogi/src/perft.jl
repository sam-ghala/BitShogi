# perft.jl
# performance testing for verifying move generation is corrrect and measuring nodes/second performace
# casue shogi engine go zoom

# count leaf nodes
function perft(state::BoardState, color::Color, depth::Int)::Int
    if depth == 0
        return 1
    end
    
    moves = generate_legal_moves(state, color)

    if depth == 1
        return length(moves)
    end

    nodes = 0
    for move in moves
        # copy state 
        new_state = copy(state)
        apply_move!(new_state, move, color)

        # more moves 
        nodes += perft(new_state, opposite(color), depth - 1)
    end
    return nodes
end

# node count per first move 
function perft_divide(state::BoardState, color::Color, depth::Int)::Int 
    moves = generate_legal_moves(state, color)
    total = 0
    for move in moves
        new_state = copy(state)
        apply_move!(new_state, move, color)
        
        nodes = depth > 1 ? perft(new_state, opposite(color), depth - 1) : 1
        total += nodes
        println("$(format_move(move)): $nodes")
    end
    println("Total: $total")
    return total
end

# run with timing
function perft_timed(state::BoardState, color::Color, depth::Int)
    start_time = time()
    nodes = perft(state, color, depth)
    elapsed = time() - start_time

    nps = elapsed > 0 ? nodes / elapsed : nodes

    println("Depth: $depth")
    println("Nodes: $nodes")
    println("Time: $(round(elapsed, digits=3)) seconds")
    println("Speed: $(round(nps / 1000, digits=1))K nodes/sec")
    
    return nodes
end

function run_perft_suite()
    if !MAGICS_INITIALIZED[]
        init_all_magics!()
    end

    state = initial_position()
    print_board(state)

    println("Initial Pos Perft")
    for depth in 1:5
        perft_timed(state, BLACK, depth)
    end
end

function quick_test()
    println("Quick perft test...")
    
    if !MAGICS_INITIALIZED[]
        init_all_magics!()
    end
    
    state = initial_position()
    
    # perft(1) should equal number of legal moves off of start
    moves = generate_legal_moves(state, BLACK)
    p1 = perft(state, BLACK, 1)
    
    println("Legal moves: $(length(moves))")
    println("Perft(1): $p1")
    
    if p1 == length(moves)
        println("Perft(1) matches legal move count")
    else
        println("mismatch")
    end
    
    println("\nPerft divide (depth 2):")
    perft_divide(state, BLACK, 2)
end

# quick_test()

