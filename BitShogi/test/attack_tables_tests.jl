@testset "Attack Tables" begin

    @testset "compute_step_attacks / KING_ATTACKS center" begin
        center = square_index(3,3)
        expected = bitboard_from_squares(7,8,9,12,14,17,18,19)
        @test KING_ATTACKS[center] == expected
        # ensure compute_step_attacks matches KING dir usage
        @test compute_step_attacks(center, ALL_DIRS) == expected
    end

    @testset "gold_attacks (black/white)" begin
        center = square_index(3,3)
        # Black gold: NORTH, NORTH_EAST, EAST, SOUTH, WEST, NORTH_WEST
        expected_black = bitboard_from_squares(8,9,14,18,12,7)
        @test gold_attacks(center, BLACK) == expected_black

        # White gold: SOUTH, SOUTH_WEST, WEST, NORTH, SOUTH_EAST, EAST
        expected_white = bitboard_from_squares(18,17,12,8,19,14)
        @test gold_attacks(center, WHITE) == expected_white
    end

    @testset "silver_attacks (black/white)" begin
        center = square_index(3,3)
        expected_black = bitboard_from_squares(8,9,7,19,17)
        expected_white = bitboard_from_squares(18,19,17,9,7)
        @test silver_attacks(center, BLACK) == expected_black
        @test silver_attacks(center, WHITE) == expected_white
    end

    @testset "knight_attacks precomputed" begin
        center = square_index(3,3)
        # black knight jumps should be to 1st rank files 2 and 4
        @test knight_attacks(center, BLACK) == compute_knight_attacks(center, BLACK)
        @test collect(squares(knight_attacks(center, BLACK))) == collect(squares(compute_knight_attacks(center, BLACK)))

        # specific expected squares
        @test knight_attacks(center, BLACK) == bitboard_from_squares(2,4)
        @test knight_attacks(center, WHITE) == bitboard_from_squares(22,24)
    end

    @testset "pawn_attacks" begin
        center = square_index(3,3)
        @test pawn_attacks(center, BLACK) == bitboard_from_squares(8)
        @test pawn_attacks(center, WHITE) == bitboard_from_squares(18)

        # edge pawn has no attack off-board
        top = square_index(1,3)
        @test pawn_attacks(top, BLACK) == EMPTY_BB
    end

    @testset "horse/dragon bonus attacks" begin
        center = square_index(3,3)
        # orthogonal bonus for horse should be same as ORTHOGONAL_DIRS step
        @test horse_bonus_attacks(center) == compute_step_attacks(center, ORTHOGONAL_DIRS)
        @test dragon_bonus_attacks(center) == compute_step_attacks(center, DIAGONAL_DIRS)
    end

    @testset "get_piece_attacks" begin
        # king
        @test get_piece_attacks(13, KING, BLACK) == KING_ATTACKS[13]
        # gold via get_piece_attacks
        @test get_piece_attacks(13, GOLD, BLACK) == gold_attacks(13, BLACK)
        # promoted bishop -> horse bonus
        @test get_piece_attacks(13, PROMOTED_BISHOP, BLACK) == horse_bonus_attacks(13)
        # promoted rook -> dragon bonus
        @test get_piece_attacks(13, PROMOTED_ROOK, BLACK) == dragon_bonus_attacks(13)
    end

    @testset "edge wrapping prevention" begin
        left_edge = square_index(3,1)
        # attempts to compute west should yield no off-board squares
        attacks = compute_step_attacks(left_edge, (WEST, NORTH_WEST, SOUTH_WEST))
        # all attacked squares should have file >=1
        for sq in collect(squares(attacks))
            @test file_of(sq) >= 1
        end
    end

    @testset "print helpers (smoke)" begin
        # ensure the print functions don't error
        print_attack_table(KING_ATTACKS, "King")
        print_color_attack_table(GOLD_ATTACKS, "Gold")
    end

end
