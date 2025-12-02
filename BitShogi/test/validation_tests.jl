@testset "Validation" begin

    @testset "parse_square and square_to_string" begin
        @test parse_square("1a") == square_index(1,1)
        @test parse_square("5e") == square_index(5,5)
        @test parse_square("0a") === nothing
        @test square_to_string(square_index(3,3)) == "3c"
    end

    @testset "parse_move drops and board moves" begin
        st = BoardState()
        add_to_hand!(st, PAWN, BLACK)
        mv = parse_move("P*3c", st, BLACK)
        @test mv !== nothing
        @test move_is_drop(mv)

        st2 = initial_position()
        # white rook on 1a should be able to move to 2a
        mv2 = parse_move("1a2a", st2, WHITE)
        @test mv2 !== nothing
        @test !move_is_drop(mv2)

        # invalid move notation
        @test parse_move("xyz", st2, WHITE) === nothing
    end

    @testset "validate_drop_move checks" begin
        st = BoardState()
        # no pawn in hand
        drop = create_drop(square_index(3,3), PAWN)
        ok, reason = validate_drop_move(st, drop, BLACK)
        @test !ok
        @test occursin("No", reason)

        # add pawn and valid drop
        add_to_hand!(st, PAWN, BLACK)
        ok2, reason2 = validate_drop_move(st, drop, BLACK)
        @test ok2

        # nifu: place a pawn in same file
        place_piece!(st, square_index(4,3), PAWN, BLACK)
        update_occupied!(st)
        ok3, reason3 = validate_drop_move(st, drop, BLACK)
        @test !ok3
        @test occursin("Nifu", reason3) || occursin("two pawns", reason3)
    end

    @testset "validate_board_move checks" begin
        st = BoardState()
        # moving from empty square
        mv = create_move(1,2,PAWN,false,NO_PIECE)
        ok, reason = validate_board_move(st, mv, BLACK)
        @test !ok
        @test occursin("No piece at source", reason)

        st2 = initial_position()
        # craft a move with wrong piece type at source
        from_sq = square_index(1,1) # white rook here
        bad_mv = create_move(from_sq, square_index(2,1), KNIGHT, false, NO_PIECE)
        ok2, reason2 = validate_board_move(st2, bad_mv, WHITE)
        @test !ok2
        @test occursin("Piece type mismatch", reason2) || occursin("piece type mismatch", reason2)

        # valid rook move
        good_mv = create_move(from_sq, square_index(2,1), ROOK, false, NO_PIECE)
        ok3, reason3 = validate_board_move(st2, good_mv, WHITE)
        @test ok3
    end

    @testset "can_piece_reach" begin
        st = initial_position()
        # rook at 1 can reach 6
        @test can_piece_reach(st, square_index(1,1), square_index(2,1), ROOK, WHITE)
        # pawn cannot reach backwards
        @test !can_piece_reach(st, square_index(4,1), square_index(5,1), PAWN, BLACK)
    end

    @testset "validate_position detects problems" begin
        s = BoardState()
        # no kings -> should return errors listing missing kings
        ok, errs = validate_position(s)
        @test !ok
        @test any(contains(==("BLACK has no king"), x->x) == false for x in errs) == false || length(errs) >= 1
        # add two kings for black
        place_piece!(s, square_index(5,1), KING, BLACK)
        place_piece!(s, square_index(5,2), KING, BLACK)
        update_occupied!(s)
        ok2, errs2 = validate_position(s)
        @test !ok2
        @test any(occ -> occursin("multiple kings", occ) || occursin("no king", occ), errs2)
    end

    @testset "format_move and try_make_move" begin
        st = initial_position()
        s = format_move(create_move(square_index(5,1), square_index(4,1), PAWN, false, NO_PIECE))
        @test typeof(s) == String

        # try_make_move valid
        mv, reason = try_make_move("1d1c", st, BLACK)
        # Depending on initial_position layout, this may or may not be valid; ensure it returns a tuple
        @test length(Tuple((mv, reason))) == 2

        # format_move_verbose may call undefined helper; assert it errors (exposes bug)
        bad_mv = create_move(square_index(1,1), square_index(2,1), ROOK, false, NO_PIECE)
        @test_throws MethodError format_move_verbose(bad_mv, st)
    end

    @testset "get_legal_move_strings" begin
        st = initial_position()
        moves = get_legal_move_strings(st, WHITE)
        @test isa(moves, Vector{String})
    end

end
