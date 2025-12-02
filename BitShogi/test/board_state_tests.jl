@testset "BoardState" begin

    @testset "Constructor and defaults" begin
        state = BoardState()
        @test state.occupied == EMPTY_BB
        @test state.occupied_by[Int(BLACK)] == EMPTY_BB
        @test state.occupied_by[Int(WHITE)] == EMPTY_BB
        @test state.king_sq == [0,0]
        @test all(x -> x == 0, state.hand[1])
        @test all(x -> x == 0, state.hand[2])
    end

    @testset "place/remove/move piece and update_occupied!" begin
        state = BoardState()
        # place a black pawn at center
        place_piece!(state, square_index(3,3), PAWN, BLACK)
        update_occupied!(state)
        @test test_bit(get_piece_bb(state, PAWN, BLACK), square_index(3,3))
        @test is_occupied_by(state, square_index(3,3), BLACK)
        @test pieces(state, BLACK) == state.occupied_by[Int(BLACK)]

        # move it to (2,3)
        move_piece!(state, square_index(3,3), square_index(2,3), PAWN, BLACK)
        update_occupied!(state)
        @test !test_bit(get_piece_bb(state, PAWN, BLACK), square_index(3,3))
        @test test_bit(get_piece_bb(state, PAWN, BLACK), square_index(2,3))

        # remove it
        remove_piece!(state, square_index(2,3), PAWN, BLACK)
        update_occupied!(state)
        @test !test_bit(get_piece_bb(state, PAWN, BLACK), square_index(2,3))
        @test !is_occupied_by(state, square_index(2,3), BLACK)
    end

    @testset "king placement and king_square cache" begin
        state = BoardState()
        place_piece!(state, square_index(5,1), KING, BLACK)
        place_piece!(state, square_index(1,5), KING, WHITE)
        update_occupied!(state)
        @test king_square(state, BLACK) == square_index(5,1)
        @test king_square(state, WHITE) == square_index(1,5)
        @test popcount(state.kings[Int(BLACK)]) == 1
        @test popcount(state.kings[Int(WHITE)]) == 1
    end

    @testset "piece_at detection" begin
        state = BoardState()
        place_piece!(state, 1, ROOK, WHITE)
        place_piece!(state, 25, ROOK, BLACK)
        update_occupied!(state)
        @test piece_at(state, 1) == (ROOK, WHITE)
        @test piece_at(state, 25) == (ROOK, BLACK)
        @test piece_at(state, 13) === nothing
    end

    @testset "hand operations" begin
        state = BoardState()
        @test !has_in_hand(state, PAWN, BLACK)
        add_to_hand!(state, PAWN, BLACK)
        @test has_in_hand(state, PAWN, BLACK)
        @test hand_count(state, PAWN, BLACK) == 1
        add_to_hand!(state, PAWN, BLACK)
        @test hand_count(state, PAWN, BLACK) == 2
        add_to_hand!(state, GOLD, BLACK)
        @test hand_count(state, GOLD, BLACK) == 1

        # remove from hand
        remove_from_hand!(state, PAWN, BLACK)
        @test hand_count(state, PAWN, BLACK) == 1

        # removing too many should throw
        remove_from_hand!(state, PAWN, BLACK)
        @test !has_in_hand(state, PAWN, BLACK)
        @test_throws ErrorException remove_from_hand!(state, PAWN, BLACK)

        # pieces_in_hand
        add_to_hand!(state, BISHOP, WHITE)
        add_to_hand!(state, ROOK, WHITE)
        pis = pieces_in_hand(state, WHITE)
        @test BISHOP in pis && ROOK in pis
    end

    @testset "hand index mapping" begin
        @test hand_index(PAWN) == 1
        @test hand_index(LANCE) == 2
        @test hand_index_to_piece(1) == PAWN
        @test hand_index_to_piece(7) == ROOK
    end

    @testset "copy semantics" begin
        s1 = BoardState()
        place_piece!(s1, 10, PAWN, WHITE)
        update_occupied!(s1)
        s2 = copy(s1)
        # mutate copy
        place_piece!(s2, 11, PAWN, WHITE)
        update_occupied!(s2)
        # original should be unchanged
        @test !test_bit(get_piece_bb(s1, PAWN, WHITE), 11)
        @test test_bit(get_piece_bb(s2, PAWN, WHITE), 11)
    end

    @testset "initial_position correctness" begin
        st = initial_position()
        update_occupied!(st)
        # white back rank
        @test piece_at(st, square_index(1,1)) == (ROOK, WHITE)
        @test piece_at(st, square_index(1,2)) == (BISHOP, WHITE)
        @test piece_at(st, square_index(1,3)) == (SILVER, WHITE)
        @test piece_at(st, square_index(1,4)) == (GOLD, WHITE)
        @test piece_at(st, square_index(1,5)) == (KING, WHITE)
        # white pawn
        @test piece_at(st, square_index(2,5)) == (PAWN, WHITE)
        # black pawn
        @test piece_at(st, square_index(4,1)) == (PAWN, BLACK)
        # black back rank
        @test piece_at(st, square_index(5,1)) == (KING, BLACK)
        @test piece_at(st, square_index(5,2)) == (GOLD, BLACK)
        @test piece_at(st, square_index(5,3)) == (SILVER, BLACK)
        @test piece_at(st, square_index(5,4)) == (BISHOP, BLACK)
        @test piece_at(st, square_index(5,5)) == (ROOK, BLACK)

        @test validate_board(st)
    end

    @testset "print_board smoke" begin
        s = initial_position()
        io = IOBuffer()
        # ensure it runs without crashing
        print_board(s)
    end

end
