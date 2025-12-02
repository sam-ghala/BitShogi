@testset "Bitboard" begin

    @testset "Square Bitboards" begin
        # Each square bitboard should have exactly one bit set
        for sq in 1:NUM_SQUARES
            bb = SQUARE_BB[sq]
            @test popcount(bb) == 1
            @test test_bit(bb, sq)
            # other squares should be unset
            for other in 1:NUM_SQUARES
                if other != sq
                    @test !test_bit(bb, other)
                end
            end
        end
    end

    @testset "Set/Clear/Test/Toggling Bits" begin
        bb = EMPTY_BB
        bb = set_bit(bb, 1)
        @test test_bit(bb, 1)
        bb = set_bit(bb, 5)
        @test test_bit(bb, 5)
        @test popcount(bb) == 2

        bb = clear_bit(bb, 1)
        @test !test_bit(bb, 1)
        @test test_bit(bb, 5)
        @test popcount(bb) == 1

        # toggle: flip bit 5 -> 0, and flip bit 3 -> 1
        bb = toggle_bit(bb, 5)
        @test !test_bit(bb, 5)
        bb = toggle_bit(bb, 3)
        @test test_bit(bb, 3)
    end

    @testset "Popcount / lsb / msb / pop_lsb" begin
        bb = bitboard_from_squares(1, 7, 13, 19, 25)
        @test popcount(bb) == 5
        @test lsb(bb) == 1
        @test msb(bb) == 25
        sq, rest = pop_lsb(bb)
        @test sq == 1
        @test !test_bit(rest, 1)
        @test popcount(rest) == 4
    end

    @testset "Iterator squares(bb)" begin
        bb = bitboard_from_squares(2,3,5)
        collected = collect(squares(bb))
        @test sort(collected) == [2,3,5]
    end

    @testset "Rank and File Masks" begin
        # rank masks
        r1 = RANK_BB[1]
        @test popcount(r1) == BOARD_SIZE
        @test all(test_bit(r1, square_index(1,f)) for f in 1:BOARD_SIZE)

        # file masks
        f1 = FILE_BB[1]
        @test popcount(f1) == BOARD_SIZE
        @test all(test_bit(f1, square_index(r,1)) for r in 1:BOARD_SIZE)

        # rank/file mask coverage
        combined = reduce(|, RANK_BB[r] for r in 1:BOARD_SIZE)
        @test combined == FULL_BB

        combined_f = reduce(|, FILE_BB[f] for f in 1:BOARD_SIZE)
        @test combined_f == FULL_BB
    end

    @testset "Promotion Masks" begin
        # Black promotion bb should include rank 1..PROMOTION_ZONE_SIZE
        @test popcount(BLACK_PROMOTION_BB) >= 1
        @test (BLACK_MUST_PROMOTE_PAWN_BB & BLACK_PROMOTION_BB) == BLACK_MUST_PROMOTE_PAWN_BB
    end

    @testset "Shift Operations" begin
        # place a single bit at center (3,3) -> sq 13
        center = set_bit(EMPTY_BB, 13)
        north = shift_north(center)
        @test test_bit(north, square_index(2,3))
        south = shift_south(center)
        @test test_bit(south, square_index(4,3))
        east  = shift_east(center)
        @test test_bit(east, square_index(3,4))
        west  = shift_west(center)
        @test test_bit(west, square_index(3,2))

        # diagonal
        ne = shift_north_east(center)
        @test test_bit(ne, square_index(2,4))
        sw = shift_south_west(center)
        @test test_bit(sw, square_index(4,2))
    end

    @testset "Helpers: empty/single/multiple" begin
        @test is_empty(EMPTY_BB)
        bb = set_bit(EMPTY_BB, 7)
        @test is_single(bb)
        bb2 = set_bit(bb, 8)
        @test is_multiple(bb2)
    end

    @testset "Bitboard Boolean Ops" begin
        a = bitboard_from_squares(1,2,3)
        b = bitboard_from_squares(3,4)
        @test bb_and(a,b) == bitboard_from_squares(3)
        @test bb_or(a,b) == bitboard_from_squares(1,2,3,4)
        @test bb_subtract(a,b) == bitboard_from_squares(1,2)
        @test bb_not(a) == (~a) & FULL_BB
    end

    @testset "Square mask helpers" begin
        @test square_bb(5) == SQUARE_BB[5]
        @test rank_bb(13) == RANK_BB[3]
        @test file_bb(13) == FILE_BB[3]
        @test same_rank(1,5)
        @test same_file(1,6)
    end

    @testset "Bitboard creation helpers" begin
        bb = bitboard_from_squares(1,7,13)
        @test test_bit(bb,1) && test_bit(bb,7) && test_bit(bb,13)

        bb2 = bitboard_from_coords((1,1), (2,2), (3,3))
        @test test_bit(bb2, square_index(1,1))
        @test test_bit(bb2, square_index(2,2))
        @test test_bit(bb2, square_index(3,3))
    end

    @testset "Print helpers (smoke)" begin
        io = IOBuffer()
        # just ensure these don't error and produce some output
        print_bitboard(bitboard_from_squares(1,5,21), "TestBoard")
        print_bitboards([("A", bitboard_from_squares(1,2)), ("B", bitboard_from_squares(3,4))])
    end

end
