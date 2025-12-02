@testset "Move Generation" begin

    @testset "Attack detection" begin
        st = BoardState()
        # place a white rook on rank1 file5 and black king on rank1 file1 with clear path
        place_piece!(st, square_index(1,5), ROOK, WHITE)
        place_piece!(st, square_index(1,1), KING, BLACK)
        update_occupied!(st)
        @test is_attacked_by(st, square_index(1,1), WHITE)
        @test is_in_check(st, BLACK)
    end

    @testset "Apply move with capture updates hand" begin
        st = BoardState()
        # Black pawn at (3,3) capture white pawn at (2,3)
        place_piece!(st, square_index(3,3), PAWN, BLACK)
        place_piece!(st, square_index(2,3), PAWN, WHITE)
        update_occupied!(st)

        move = create_move(square_index(3,3), square_index(2,3), PAWN, false, UInt8(PAWN))
        apply_move!(st, move, BLACK)
        # white pawn removed
        @test piece_at(st, square_index(2,3)) == (PAWN, BLACK)
        # captured pawn should be in black's hand (demoted PAWN -> PAWN index 1)
        @test hand_count(st, PAWN, BLACK) == 1
    end

    @testset "Promotion rules" begin
        # pawn must promote when moving to last rank
        st = BoardState()
        # place black pawn on rank2 file1 and ensure moving to rank1 must promote
        place_piece!(st, square_index(2,1), PAWN, BLACK)
        update_occupied!(st)
        moves = Move[]
        generate_pawn_moves!(moves, st, BLACK)
        # find move that goes to rank1
        has_promote = any(move_is_promotion(m) && rank_of(move_to(m)) == 1 for m in moves)
        @test has_promote

        # knight must promote when landing on rank1 or 2? For black, must_promote when rank <=2
        @test must_promote(KNIGHT, square_index(1,3), BLACK)
        @test must_promote(KNIGHT, square_index(2,3), BLACK)
        @test !must_promote(KNIGHT, square_index(3,3), BLACK)
    end

    @testset "Drop square rules (pawn nifu and last rank)" begin
        st = BoardState()
        # place a black pawn on file 1 to simulate nifu
        place_piece!(st, square_index(4,1), PAWN, BLACK)
        update_occupied!(st)
        empty = empty_squares(st)
        valid = get_valid_drop_squares(st, PAWN, BLACK, empty)
        # no squares on file 1 should be valid
        @test (valid & FILE_BB[1]) == EMPTY_BB

        # pawn cannot be dropped on last rank
        if BLACK == BLACK
            @test (valid & RANK_BB[BLACK_MUST_PROMOTE_RANK]) == EMPTY_BB
        end

        # Knight drops excluded on last two ranks for black
        valid_knight = get_valid_drop_squares(st, KNIGHT, BLACK, empty)
        @test (valid_knight & RANK_BB[1]) == EMPTY_BB
    end

    @testset "Drop generation and legal move filtering" begin
        st = initial_position()
        update_occupied!(st)
        # ensure pseudo legal moves non-empty
        pseudo = generate_pseudo_legal_moves(st, BLACK)
        @test length(pseudo) > 0
        legal = generate_legal_moves(st, BLACK)
        @test length(legal) > 0
        @test count_legal_moves(st, BLACK) == length(legal)
    end

    @testset "is_uchifuzume basic (non-mate)" begin
        st = BoardState()
        # simple case: drop pawn not checking king
        place_piece!(st, square_index(1,1), KING, WHITE)
        place_piece!(st, square_index(5,5), KING, BLACK)
        update_occupied!(st)
        move = create_drop(square_index(3,3), PAWN)
        @test !is_uchifuzume(st, move, BLACK)
    end

    @testset "is_legal_move prevents leaving king in check" begin
        st = BoardState()
        # Black king on 5,1; white rook attacking along rank if black moves a blocking piece
        place_piece!(st, square_index(5,1), KING, BLACK)
        place_piece!(st, square_index(5,2), PAWN, BLACK)
        place_piece!(st, square_index(5,5), ROOK, WHITE)
        update_occupied!(st)
        # moving the pawn at 5,2 away may expose king to rook; test that a move that leaves king in check is illegal
        mv = create_move(square_index(5,2), square_index(4,2), PAWN, false, NO_PIECE)
        @test !is_legal_move(st, mv, BLACK)
    end

    @testset "move_to_string formatting (board moves)" begin
        mv = create_move(square_index(5,2), square_index(4,2), PAWN, true, NO_PIECE)
        s = move_to_string(mv)
        # should contain a dash and a '+' for promotion
        @test occursin('-', s)
        @test occursin('+', s)
    end

end
