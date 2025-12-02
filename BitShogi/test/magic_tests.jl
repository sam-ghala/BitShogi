@testset "Magic" begin

    @testset "trace_ray basic" begin
        # center square (3,3) = 13
        sq = square_index(3,3)
        # no blockers: north should hit 8 and 3
        attacks = trace_ray(sq, NORTH, EMPTY_BB)
        @test sort(collect(squares(attacks))) == [3,8]

        # blocker at 8 stops ray
        blockers = set_bit(EMPTY_BB, 8)
        attacks2 = trace_ray(sq, NORTH, blockers)
        @test sort(collect(squares(attacks2))) == [8]

        # ray wrapping prevention: from file=1 west should be empty
        left_edge_sq = square_index(3,1)
        @test is_empty(trace_ray(left_edge_sq, WEST, EMPTY_BB))
    end

    @testset "rook_attacks_slow" begin
        sq = square_index(3,3)
        attacks = rook_attacks_slow(sq, EMPTY_BB)
        expected = bitboard_from_squares(3,8,11,12,14,15,18,23)
        @test attacks == expected

        # with a blocker at 14 (east immediate) east ray stops at 14
        blockers = set_bit(EMPTY_BB, 14)
        attacks_b = rook_attacks_slow(sq, blockers)
        @test test_bit(attacks_b, 14)
        @test !test_bit(attacks_b, 15)
    end

    @testset "bishop_attacks_slow" begin
        sq = square_index(3,3)
        attacks = bishop_attacks_slow(sq, EMPTY_BB)
        expected = bitboard_from_squares(1,5,7,9,17,19,21,25)
        @test attacks == expected

        # blocker at 19 (SE) stops that diagonal
        blockers = set_bit(EMPTY_BB, 19)
        attacks_b = bishop_attacks_slow(sq, blockers)
        @test test_bit(attacks_b, 19)
        @test !test_bit(attacks_b, 25)
    end

    @testset "lance_attacks_slow" begin
        # black lance moves north
        sq = square_index(5,3) # rank5 file3 -> near bottom
        attacks_black = lance_attacks_slow(sq, EMPTY_BB, BLACK)
        # from rank5 north: 4,3,2,1 but trace_ray stops at edge -> include 4,3,2,1
        expected_black = bitboard_from_squares(square_index(4,3), square_index(3,3), square_index(2,3), square_index(1,3))
        @test attacks_black == expected_black

        # white lance moves south
        sqw = square_index(1,3) # rank1 file3
        attacks_white = lance_attacks_slow(sqw, EMPTY_BB, WHITE)
        expected_white = bitboard_from_squares(square_index(2,3), square_index(3,3), square_index(4,3), square_index(5,3))
        @test attacks_white == expected_white
    end

    @testset "compute masks" begin
        # compute_rook_mask for center sq should include only inner squares (excluding edges)
        sq = square_index(3,3)
        mask = compute_rook_mask(sq)
        expected_mask = bitboard_from_squares(8,18,12,14)
        @test mask == expected_mask

        # compute_bishop_mask for center should include only immediate inner diagonals
        bmask = compute_bishop_mask(sq)
        expected_bmask = bitboard_from_squares(7,9,17,19)
        @test bmask == expected_bmask

        # compute_lance_mask for rank 2, black should be empty (no intermediate squares)
        sq2 = square_index(2,3)
        lmask = compute_lance_mask(sq2, BLACK)
        @test lmask == EMPTY_BB

        # compute_lance_mask for rank 3, black should include rank2
        sq3 = square_index(3,3)
        lmask2 = compute_lance_mask(sq3, BLACK)
        @test lmask2 == bitboard_from_squares(square_index(2,3))
    end

    @testset "enumerate_occupancies" begin
        mask = bitboard_from_squares(2,3)
        occs = enumerate_occupancies(mask)
        # should contain empty, 2,3, 2|3
        expected = Set([EMPTY_BB, bitboard_from_squares(2), bitboard_from_squares(3), bitboard_from_squares(2,3)])
        @test Set(occs) == expected
    end

    @testset "find_lance_magic empty mask" begin
        sq = square_index(2,3)
        mask = compute_lance_mask(sq, BLACK)
        @test mask == EMPTY_BB
        magic, shift, table = find_lance_magic(sq, mask, BLACK)
        @test magic == Bitboard(0)
        @test shift == 0
        @test length(table) == 1
        @test table[1] == lance_attacks_slow(sq, EMPTY_BB, BLACK)
    end

end
