@testset "Types" begin
    
    # =========================================================================
    # SECTION 1: Color Enum and Operations
    # =========================================================================
    @testset "Color Enum" begin
        @test BLACK == Color(1)
        @test WHITE == Color(2)
        @test Int(BLACK) == 1
        @test Int(WHITE) == 2
    end
    
    @testset "Color Operations" begin
        # Test opposite color
        @test opposite(BLACK) == WHITE
        @test opposite(WHITE) == BLACK
        
        # Test opposite is idempotent
        @test opposite(opposite(BLACK)) == BLACK
        @test opposite(opposite(WHITE)) == WHITE
        
        # Test XOR trick property
        @test UInt8(BLACK) ⊻ 0x03 == UInt8(WHITE)
        @test UInt8(WHITE) ⊻ 0x03 == UInt8(BLACK)
    end
    
    # =========================================================================
    # SECTION 2: PieceType Enum
    # =========================================================================
    @testset "PieceType Base Pieces" begin
        # Base pieces (1-8)
        @test PAWN == PieceType(1)
        @test LANCE == PieceType(2)
        @test KNIGHT == PieceType(3)
        @test SILVER == PieceType(4)
        @test GOLD == PieceType(5)
        @test BISHOP == PieceType(6)
        @test ROOK == PieceType(7)
        @test KING == PieceType(8)
    end
    
    @testset "PieceType Promoted Pieces" begin
        # Promoted pieces (9-14)
        @test PROMOTED_PAWN == PieceType(9)
        @test PROMOTED_LANCE == PieceType(10)
        @test PROMOTED_KNIGHT == PieceType(11)
        @test PROMOTED_SILVER == PieceType(12)
        @test PROMOTED_BISHOP == PieceType(13)
        @test PROMOTED_ROOK == PieceType(14)
    end
    
    # =========================================================================
    # SECTION 3: Promotion Functions
    # =========================================================================
    @testset "is_promoted" begin
        # Base pieces are not promoted
        @test !is_promoted(PAWN)
        @test !is_promoted(LANCE)
        @test !is_promoted(KNIGHT)
        @test !is_promoted(SILVER)
        @test !is_promoted(GOLD)
        @test !is_promoted(BISHOP)
        @test !is_promoted(ROOK)
        @test !is_promoted(KING)
        
        # Promoted pieces are promoted
        @test is_promoted(PROMOTED_PAWN)
        @test is_promoted(PROMOTED_LANCE)
        @test is_promoted(PROMOTED_KNIGHT)
        @test is_promoted(PROMOTED_SILVER)
        @test is_promoted(PROMOTED_BISHOP)
        @test is_promoted(PROMOTED_ROOK)
    end
    
    @testset "can_promote" begin
        # Can promote
        @test can_promote(PAWN)
        @test can_promote(LANCE)
        @test can_promote(KNIGHT)
        @test can_promote(SILVER)
        @test can_promote(BISHOP)
        @test can_promote(ROOK)
        
        # Cannot promote
        @test !can_promote(GOLD)
        @test !can_promote(KING)
        
        # Cannot promote already promoted pieces
        @test !can_promote(PROMOTED_PAWN)
        @test !can_promote(PROMOTED_ROOK)
    end
    
    @testset "promote" begin
        # Correct promotions
        @test promote(PAWN) == PROMOTED_PAWN
        @test promote(LANCE) == PROMOTED_LANCE
        @test promote(KNIGHT) == PROMOTED_KNIGHT
        @test promote(SILVER) == PROMOTED_SILVER
        @test promote(BISHOP) == PROMOTED_BISHOP
        @test promote(ROOK) == PROMOTED_ROOK
        
        # Promoting non-promotable pieces should error
        @test_throws ErrorException promote(GOLD)
        @test_throws ErrorException promote(KING)
    end
    
    @testset "demote" begin
        # Demotion of promoted pieces
        @test demote(PROMOTED_PAWN) == PAWN
        @test demote(PROMOTED_LANCE) == LANCE
        @test demote(PROMOTED_KNIGHT) == KNIGHT
        @test demote(PROMOTED_SILVER) == SILVER
        @test demote(PROMOTED_BISHOP) == BISHOP
        @test demote(PROMOTED_ROOK) == ROOK
        
        # Base pieces stay the same
        @test demote(PAWN) == PAWN
        @test demote(LANCE) == LANCE
        @test demote(KNIGHT) == KNIGHT
        @test demote(SILVER) == SILVER
        @test demote(GOLD) == GOLD
        @test demote(BISHOP) == BISHOP
        @test demote(ROOK) == ROOK
        @test demote(KING) == KING
    end
    
    @testset "promote/demote round-trip" begin
        # Round-trip for promotable pieces
        @test demote(promote(PAWN)) == PAWN
        @test demote(promote(LANCE)) == LANCE
        @test demote(promote(KNIGHT)) == KNIGHT
        @test demote(promote(SILVER)) == SILVER
        @test demote(promote(BISHOP)) == BISHOP
        @test demote(promote(ROOK)) == ROOK
    end
    
    # =========================================================================
    # SECTION 4: Piece Characteristics
    # =========================================================================
    @testset "is_slider" begin
        # Sliders: LANCE, BISHOP, ROOK and their promoted versions
        @test is_slider(LANCE)
        @test is_slider(BISHOP)
        @test is_slider(ROOK)
        @test is_slider(PROMOTED_BISHOP)
        @test is_slider(PROMOTED_ROOK)
        
        # Non-sliders
        @test !is_slider(PAWN)
        @test !is_slider(KNIGHT)
        @test !is_slider(SILVER)
        @test !is_slider(GOLD)
        @test !is_slider(KING)
        @test !is_slider(PROMOTED_PAWN)
        @test !is_slider(PROMOTED_LANCE)
        @test !is_slider(PROMOTED_KNIGHT)
        @test !is_slider(PROMOTED_SILVER)
    end
    
    @testset "moves_like_gold" begin
        # Pieces that move like gold
        @test moves_like_gold(GOLD)
        @test moves_like_gold(PROMOTED_PAWN)
        @test moves_like_gold(PROMOTED_LANCE)
        @test moves_like_gold(PROMOTED_KNIGHT)
        @test moves_like_gold(PROMOTED_SILVER)
        
        # Pieces that don't move like gold
        @test !moves_like_gold(PAWN)
        @test !moves_like_gold(LANCE)
        @test !moves_like_gold(KNIGHT)
        @test !moves_like_gold(SILVER)
        @test !moves_like_gold(BISHOP)
        @test !moves_like_gold(ROOK)
        @test !moves_like_gold(KING)
        @test !moves_like_gold(PROMOTED_BISHOP)
        @test !moves_like_gold(PROMOTED_ROOK)
    end
    
    # =========================================================================
    # SECTION 5: Piece Collections
    # =========================================================================
    @testset "Minishogi Pieces" begin
        @test PAWN in MINISHOGI_PIECES
        @test SILVER in MINISHOGI_PIECES
        @test GOLD in MINISHOGI_PIECES
        @test BISHOP in MINISHOGI_PIECES
        @test ROOK in MINISHOGI_PIECES
        @test KING in MINISHOGI_PIECES
        @test PROMOTED_PAWN in MINISHOGI_PIECES
        @test PROMOTED_SILVER in MINISHOGI_PIECES
        @test PROMOTED_BISHOP in MINISHOGI_PIECES
        @test PROMOTED_ROOK in MINISHOGI_PIECES
        
        # Standard pieces not in minishogi
        @test !(LANCE in MINISHOGI_PIECES)
        @test !(KNIGHT in MINISHOGI_PIECES)
        @test !(PROMOTED_LANCE in MINISHOGI_PIECES)
        @test !(PROMOTED_KNIGHT in MINISHOGI_PIECES)
        
        @test length(MINISHOGI_PIECES) == 10
    end
    
    @testset "Hand Piece Types" begin
        @test PAWN in HAND_PIECE_TYPES
        @test LANCE in HAND_PIECE_TYPES
        @test KNIGHT in HAND_PIECE_TYPES
        @test SILVER in HAND_PIECE_TYPES
        @test GOLD in HAND_PIECE_TYPES
        @test BISHOP in HAND_PIECE_TYPES
        @test ROOK in HAND_PIECE_TYPES
        
        # Kings cannot be in hand
        @test !(KING in HAND_PIECE_TYPES)
        
        @test length(HAND_PIECE_TYPES) == 7
    end
    
    @testset "Minishogi Hand Piece Types" begin
        @test PAWN in MINISHOGI_HAND_PIECE_TYPES
        @test SILVER in MINISHOGI_HAND_PIECE_TYPES
        @test GOLD in MINISHOGI_HAND_PIECE_TYPES
        @test BISHOP in MINISHOGI_HAND_PIECE_TYPES
        @test ROOK in MINISHOGI_HAND_PIECE_TYPES
        
        # Not in minishogi hand
        @test !(LANCE in MINISHOGI_HAND_PIECE_TYPES)
        @test !(KNIGHT in MINISHOGI_HAND_PIECE_TYPES)
        @test !(KING in MINISHOGI_HAND_PIECE_TYPES)
        
        @test length(MINISHOGI_HAND_PIECE_TYPES) == 5
    end
    
    # =========================================================================
    # SECTION 6: Square Index Functions
    # =========================================================================
    @testset "square_index" begin
        # Corners
        @test square_index(1, 1) == 1
        @test square_index(1, 5) == 5
        @test square_index(5, 1) == 21
        @test square_index(5, 5) == 25
        
        # Center
        @test square_index(3, 3) == 13
        
        # Edge cases
        @test square_index(1, 2) == 2
        @test square_index(2, 1) == 6
    end
    
    @testset "rank_of and file_of" begin
        # Test corners
        @test rank_of(1) == 1 && file_of(1) == 1
        @test rank_of(5) == 1 && file_of(5) == 5
        @test rank_of(21) == 5 && file_of(21) == 1
        @test rank_of(25) == 5 && file_of(25) == 5
        
        # Test center
        @test rank_of(13) == 3 && file_of(13) == 3
        
        # Round-trip test
        for rank in 1:5
            for file in 1:5
                sq = square_index(rank, file)
                @test rank_of(sq) == rank
                @test file_of(sq) == file
            end
        end
    end
    
    @testset "is_valid_square" begin
        @test is_valid_square(1)
        @test is_valid_square(13)
        @test is_valid_square(25)
        @test !is_valid_square(0)
        @test !is_valid_square(26)
        @test !is_valid_square(-1)
        @test !is_valid_square(100)
    end
    
    # =========================================================================
    # SECTION 7: Move Type and Functions
    # =========================================================================
    @testset "Move Type" begin
        @test Move == UInt32
        @test NULL_MOVE == Move(0)
    end
    
    @testset "create_move" begin
        move = create_move(1, 13, PAWN, false, NO_PIECE)
        @test move_from(move) == 1
        @test move_to(move) == 13
        @test move_piece(move) == PAWN
        @test !move_is_promotion(move)
        @test move_capture(move) == NO_PIECE
        @test !move_is_drop(move)
        @test !move_is_capture(move)
    end
    
    @testset "create_move with promotion" begin
        move = create_move(3, 2, PAWN, true, NO_PIECE)
        @test move_from(move) == 3
        @test move_to(move) == 2
        @test move_piece(move) == PAWN
        @test move_is_promotion(move)
        @test !move_is_capture(move)
    end
    
    @testset "create_move with capture" begin
        move = create_move(13, 8, ROOK, false, UInt8(SILVER))
        @test move_from(move) == 13
        @test move_to(move) == 8
        @test move_piece(move) == ROOK
        @test move_capture(move) == UInt8(SILVER)
        @test move_is_capture(move)
        @test !move_is_promotion(move)
    end
    
    @testset "create_drop" begin
        move = create_drop(13, PAWN)
        @test move_from(move) == NO_SQUARE
        @test move_to(move) == 13
        @test move_piece(move) == PAWN
        @test move_is_drop(move)
        @test move_capture(move) == NO_PIECE
        @test !move_is_capture(move)
    end
    
    @testset "move_is_drop" begin
        regular_move = create_move(1, 13, PAWN, false, NO_PIECE)
        drop_move = create_drop(13, PAWN)
        
        @test !move_is_drop(regular_move)
        @test move_is_drop(drop_move)
    end
    
    @testset "move_is_capture" begin
        no_capture = create_move(1, 13, PAWN, false, NO_PIECE)
        capture = create_move(1, 13, PAWN, false, UInt8(SILVER))
        
        @test !move_is_capture(no_capture)
        @test move_is_capture(capture)
    end
    
    # =========================================================================
    # SECTION 8: Piece Type and Color Encoding
    # =========================================================================
    @testset "create_piece and accessors" begin
        piece_black = create_piece(PAWN, BLACK)
        piece_white = create_piece(ROOK, WHITE)
        
        @test piece_type(piece_black) == PAWN
        @test piece_color(piece_black) == BLACK
        
        @test piece_type(piece_white) == ROOK
        @test piece_color(piece_white) == WHITE
    end
    
    @testset "Piece encoding round-trip" begin
        for pt in (PAWN, SILVER, GOLD, BISHOP, ROOK, KING)
            for color in (BLACK, WHITE)
                piece = create_piece(pt, color)
                @test piece_type(piece) == pt
                @test piece_color(piece) == color
            end
        end
    end
    
    # =========================================================================
    # SECTION 9: GameStatus Enum
    # =========================================================================
    @testset "GameStatus Values" begin
        @test ONGOING == GameStatus(0)
        @test BLACK_WINS_CHECKMATE == GameStatus(1)
        @test WHITE_WINS_CHECKMATE == GameStatus(2)
        @test BLACK_WINS_RESIGNATION == GameStatus(3)
        @test WHITE_WINS_RESIGNATION == GameStatus(4)
        @test DRAW_REPETITION == GameStatus(5)
        @test DRAW_STALEMATE == GameStatus(6)
        @test DRAW_IMPASSE == GameStatus(7)
    end
    
    # =========================================================================
    # SECTION 10: SFEN Mappings
    # =========================================================================
    @testset "SFEN_TO_PIECE" begin
        # Black pieces
        @test SFEN_TO_PIECE['P'] == (PAWN, BLACK)
        @test SFEN_TO_PIECE['K'] == (KING, BLACK)
        @test SFEN_TO_PIECE['R'] == (ROOK, BLACK)
        
        # White pieces
        @test SFEN_TO_PIECE['p'] == (PAWN, WHITE)
        @test SFEN_TO_PIECE['k'] == (KING, WHITE)
        @test SFEN_TO_PIECE['r'] == (ROOK, WHITE)
        
        # Check all pieces are in dictionary
        @test haskey(SFEN_TO_PIECE, 'P')
        @test haskey(SFEN_TO_PIECE, 'p')
        @test length(SFEN_TO_PIECE) == 16  # 8 piece types × 2 colors
    end
    
    @testset "PIECE_TO_SFEN" begin
        # Base pieces
        @test PIECE_TO_SFEN[(PAWN, BLACK)] == "P"
        @test PIECE_TO_SFEN[(KING, BLACK)] == "K"
        @test PIECE_TO_SFEN[(PAWN, WHITE)] == "p"
        @test PIECE_TO_SFEN[(KING, WHITE)] == "k"
        
        # Promoted pieces
        @test PIECE_TO_SFEN[(PROMOTED_PAWN, BLACK)] == "+P"
        @test PIECE_TO_SFEN[(PROMOTED_PAWN, WHITE)] == "+p"
        @test PIECE_TO_SFEN[(PROMOTED_ROOK, BLACK)] == "+R"
        @test PIECE_TO_SFEN[(PROMOTED_ROOK, WHITE)] == "+r"
        
        # All base and promoted pieces should be mapped
        @test length(PIECE_TO_SFEN) == 28  # 8 base + 6 promoted × 2 colors
    end
    
    @testset "SFEN Round-trip" begin
        for (sfen_char, (pt, color)) in SFEN_TO_PIECE
            result_sfen = PIECE_TO_SFEN[(pt, color)]
            @test result_sfen == string(sfen_char)
        end
    end
    
    @testset "PROMOTED_SFEN_PREFIX" begin
        @test PROMOTED_SFEN_PREFIX == '+'
    end
    
end
