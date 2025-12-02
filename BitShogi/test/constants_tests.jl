@testset "Constants" begin
    
    # =========================================================================
    # SECTION 1: Board Dimensions
    # =========================================================================
    @testset "Board Dimensions" begin
        @test BOARD_SIZE == 5
        @test NUM_SQUARES == 25
        @test Bitboard == UInt32
    end
    
    # =========================================================================
    # SECTION 2: Piece Configuration
    # =========================================================================
    @testset "Piece Configuration" begin
        @test NUM_PIECE_TYPES == 10
        @test NUM_HAND_PIECE_TYPES == 5
        @test MAX_HAND_COUNT == 2
    end
    
    # =========================================================================
    # SECTION 3: Promotion Zones
    # =========================================================================
    @testset "Promotion Zones" begin
        @test PROMOTION_ZONE_SIZE == 2
        @test BLACK_PROMOTION_RANKS == 1:2
        @test WHITE_PROMOTION_RANKS == 4:5
        @test BLACK_MUST_PROMOTE_RANK == 1
        @test WHITE_MUST_PROMOTE_RANK == 5
        
        # Verify black promotion ranks are at top
        @test first(BLACK_PROMOTION_RANKS) == 1
        @test last(BLACK_PROMOTION_RANKS) == PROMOTION_ZONE_SIZE
        
        # Verify white promotion ranks are at bottom
        @test first(WHITE_PROMOTION_RANKS) == BOARD_SIZE - PROMOTION_ZONE_SIZE + 1
        @test last(WHITE_PROMOTION_RANKS) == BOARD_SIZE
    end
    
    # =========================================================================
    # SECTION 4: Starting Position
    # =========================================================================
    @testset "Starting Position SFEN" begin
        @test INITIAL_SFEN == "rbsgk/4p/5/P4/KGSBR b - 1"
        
        # Verify SFEN structure has all components
        parts = split(INITIAL_SFEN)
        @test length(parts) == 4  # board, side, hand, move number
        
        # Board should have 5 ranks
        board_parts = split(parts[1], '/')
        @test length(board_parts) == 5
        
        # Side to move
        @test parts[2] == "b"  # Black to move
        
        # Hand pieces (none initially)
        @test parts[3] == "-"
        
        # Move number
        @test parts[4] == "1"
    end
    
    # =========================================================================
    # SECTION 5: Square Indexing
    # =========================================================================
    @testset "Square Indexing" begin
        # Square indexing formula: square = (rank - 1) * BOARD_SIZE + file
        
        # Corner squares
        @test (0 * BOARD_SIZE) + 1 == 1      # a1 (rank 1, file 1)
        @test (0 * BOARD_SIZE) + 5 == 5      # e1 (rank 1, file 5)
        @test (4 * BOARD_SIZE) + 1 == 21     # a5 (rank 5, file 1)
        @test (4 * BOARD_SIZE) + 5 == 25     # e5 (rank 5, file 5)
        
        # Center square
        @test (2 * BOARD_SIZE) + 3 == 13     # c3 (rank 3, file 3)
        
        # All squares should be in range 1-25
        @test all(1 <= sq <= NUM_SQUARES for sq in 1:NUM_SQUARES)
    end
    
    # =========================================================================
    # SECTION 6: Direction Vectors
    # =========================================================================
    @testset "Direction Vectors" begin
        # Orthogonal directions
        @test NORTH == -BOARD_SIZE        # -5: one rank up
        @test SOUTH == BOARD_SIZE         # +5: one rank down
        @test EAST == 1                   # +1: one file right
        @test WEST == -1                  # -1: one file left
        
        # Diagonal directions
        @test NORTH_EAST == NORTH + EAST       # -4
        @test NORTH_WEST == NORTH + WEST       # -6
        @test SOUTH_EAST == SOUTH + EAST       # +6
        @test SOUTH_WEST == SOUTH + WEST       # +4
        
        # Direction collections
        @test length(ORTHOGONAL_DIRS) == 4
        @test NORTH in ORTHOGONAL_DIRS
        @test SOUTH in ORTHOGONAL_DIRS
        @test EAST in ORTHOGONAL_DIRS
        @test WEST in ORTHOGONAL_DIRS
        
        @test length(DIAGONAL_DIRS) == 4
        @test NORTH_EAST in DIAGONAL_DIRS
        @test NORTH_WEST in DIAGONAL_DIRS
        @test SOUTH_EAST in DIAGONAL_DIRS
        @test SOUTH_WEST in DIAGONAL_DIRS
        
        @test length(ALL_DIRS) == 8
        @test all(d in ALL_DIRS for d in ORTHOGONAL_DIRS)
        @test all(d in ALL_DIRS for d in DIAGONAL_DIRS)
    end
    
    # =========================================================================
    # SECTION 7: Bitboard Constants
    # =========================================================================
    @testset "Bitboard Constants" begin
        @test EMPTY_BB == Bitboard(0)
        @test FULL_BB == Bitboard((1 << NUM_SQUARES) - 1)
        @test FULL_BB == Bitboard(0x01FFFFFF)  # 25 bits set
        @test NO_SQUARE == 0
        
        # Verify full bitboard has exactly NUM_SQUARES bits
        @test count_ones(FULL_BB) == NUM_SQUARES
    end
    
    # =========================================================================
    # Consistency Tests
    # =========================================================================
    @testset "Consistency Checks" begin
        # Board size consistency
        @test BOARD_SIZE > 0
        @test NUM_SQUARES == BOARD_SIZE * BOARD_SIZE
        
        # Promotion zone consistency
        @test PROMOTION_ZONE_SIZE >= 1
        @test PROMOTION_ZONE_SIZE <= BOARD_SIZE ÷ 2
        
        # Direction magnitude consistency
        @test abs(NORTH) == BOARD_SIZE
        @test abs(SOUTH) == BOARD_SIZE
        @test abs(EAST) == 1
        @test abs(WEST) == 1
        
        # Direction opposites
        @test NORTH == -SOUTH
        @test EAST == -WEST
        
        # Diagonal directions are combinations of orthogonal
        @test NORTH_EAST == NORTH + EAST
        @test NORTH_WEST == NORTH + WEST
        @test SOUTH_EAST == SOUTH + EAST
        @test SOUTH_WEST == SOUTH + WEST
    end
    
end
