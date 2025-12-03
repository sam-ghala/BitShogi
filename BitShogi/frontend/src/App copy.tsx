import { useState, useEffect, useCallback } from 'react';
import { GameState, Piece, Selection, PieceType, Color } from './types/game';
import * as api from './api/client';

// Piece image paths - maps piece types to SVG filenames
const PIECE_IMAGES: Record<string, string> = {
  PAWN: '/pieces/pawn.svg',
  SILVER: '/pieces/silver.svg',
  GOLD: '/pieces/gold.svg',
  BISHOP: '/pieces/bishop.svg',
  ROOK: '/pieces/rook.svg',
  KING: '/pieces/king.svg',
  PROMOTED_PAWN: '/pieces/pawn-p.svg',
  PROMOTED_SILVER: '/pieces/silver-p.svg',
  PROMOTED_BISHOP: '/pieces/bishop-p.svg',
  PROMOTED_ROOK: '/pieces/rook-p.svg',
  // Fallbacks for standard shogi (not used in minishogi but keeping for compatibility)
  LANCE: '/pieces/lance.svg',
  KNIGHT: '/pieces/knight.svg',
  PROMOTED_LANCE: '/pieces/lance-p.svg',
  PROMOTED_KNIGHT: '/pieces/knight-p.svg',
};

// Fallback kanji symbols (used if SVG not found)
const PIECE_SYMBOLS: Record<string, string> = {
  PAWN: '歩', LANCE: '香', KNIGHT: '桂', SILVER: '銀',
  GOLD: '金', BISHOP: '角', ROOK: '飛', KING: '王',
  PROMOTED_PAWN: 'と', PROMOTED_LANCE: '杏', PROMOTED_KNIGHT: '圭',
  PROMOTED_SILVER: '全', PROMOTED_BISHOP: '馬', PROMOTED_ROOK: '龍',
};

// Piece component - renders SVG image with fallback to kanji
function PieceImage({ type, className }: { type: string; className?: string }) {
  const imgSrc = PIECE_IMAGES[type];
  const fallback = PIECE_SYMBOLS[type] || '?';
  
  return (
    <img 
      src={imgSrc} 
      alt={type}
      className={`piece-img ${className || ''}`}
      onError={(e) => {
        // If SVG fails to load, replace with text fallback
        const target = e.target as HTMLImageElement;
        target.style.display = 'none';
        const span = document.createElement('span');
        span.textContent = fallback;
        span.className = 'piece-fallback';
        target.parentNode?.appendChild(span);
      }}
    />
  );
}

// Parse SFEN to get board pieces
function parseSfenBoard(sfen: string): Map<string, Piece> {
  const pieces = new Map<string, Piece>();
  const boardPart = sfen.split(' ')[0];
  const ranks = boardPart.split('/');
  
  const pieceMap: Record<string, { type: PieceType; color: Color }> = {
    'P': { type: 'PAWN', color: 'BLACK' },
    'L': { type: 'LANCE', color: 'BLACK' },
    'N': { type: 'KNIGHT', color: 'BLACK' },
    'S': { type: 'SILVER', color: 'BLACK' },
    'G': { type: 'GOLD', color: 'BLACK' },
    'B': { type: 'BISHOP', color: 'BLACK' },
    'R': { type: 'ROOK', color: 'BLACK' },
    'K': { type: 'KING', color: 'BLACK' },
    'p': { type: 'PAWN', color: 'WHITE' },
    'l': { type: 'LANCE', color: 'WHITE' },
    'n': { type: 'KNIGHT', color: 'WHITE' },
    's': { type: 'SILVER', color: 'WHITE' },
    'g': { type: 'GOLD', color: 'WHITE' },
    'b': { type: 'BISHOP', color: 'WHITE' },
    'r': { type: 'ROOK', color: 'WHITE' },
    'k': { type: 'KING', color: 'WHITE' },
  };
  
  const promotedMap: Record<string, PieceType> = {
    'P': 'PROMOTED_PAWN', 'L': 'PROMOTED_LANCE', 'N': 'PROMOTED_KNIGHT',
    'S': 'PROMOTED_SILVER', 'B': 'PROMOTED_BISHOP', 'R': 'PROMOTED_ROOK',
    'p': 'PROMOTED_PAWN', 'l': 'PROMOTED_LANCE', 'n': 'PROMOTED_KNIGHT',
    's': 'PROMOTED_SILVER', 'b': 'PROMOTED_BISHOP', 'r': 'PROMOTED_ROOK',
  };
  
  ranks.forEach((rankStr, rankIdx) => {
    const rank = rankIdx + 1;
    let file = 1;
    let nextIsPromoted = false;
    
    for (const char of rankStr) {
      if (char === '+') {
        nextIsPromoted = true;
        continue;
      }
      
      if (/\d/.test(char)) {
        file += parseInt(char);
        nextIsPromoted = false;
        continue;
      }
      
      const pieceInfo = pieceMap[char];
      if (pieceInfo) {
        const notation = `${file}${String.fromCharCode(96 + rank)}`;
        const type = nextIsPromoted ? promotedMap[char] : pieceInfo.type;
        pieces.set(notation, { type, color: pieceInfo.color });
        file++;
        nextIsPromoted = false;
      }
    }
  });
  
  return pieces;
}

// Get piece char for drop move notation
function getPieceChar(type: PieceType): string {
  const map: Record<string, string> = {
    PAWN: 'P', LANCE: 'L', KNIGHT: 'N', SILVER: 'S',
    GOLD: 'G', BISHOP: 'B', ROOK: 'R',
  };
  return map[type] || '?';
}

// Check if a piece type is promoted
function isPromoted(type: PieceType): boolean {
  return type.startsWith('PROMOTED_');
}

// SVG Board Lines Component
function BoardLines() {
  const size = 64;
  const lines: JSX.Element[] = [];
  
  for (let row = 0; row < 5; row++) {
    for (let col = 0; col < 5; col++) {
      const cx = col * size + size / 2;
      const cy = row * size + size / 2;
      
      // Horizontal line (right)
      if (col < 4) {
        lines.push(
          <line key={`h-${row}-${col}`} x1={cx} y1={cy} x2={cx + size} y2={cy} />
        );
      }
      // Vertical line (down)
      if (row < 4) {
        lines.push(
          <line key={`v-${row}-${col}`} x1={cx} y1={cy} x2={cx} y2={cy + size} />
        );
      }
      // Diagonal down-right
      if (col < 4 && row < 4) {
        lines.push(
          <line key={`dr-${row}-${col}`} x1={cx} y1={cy} x2={cx + size} y2={cy + size} />
        );
      }
      // Diagonal down-left
      if (col > 0 && row < 4) {
        lines.push(
          <line key={`dl-${row}-${col}`} x1={cx} y1={cy} x2={cx - size} y2={cy + size} />
        );
      }
    }
  }
  
  return (
    <svg className="board-lines" width={5 * size} height={5 * size}>
      {lines}
    </svg>
  );
}

function App() {
  const [game, setGame] = useState<GameState | null>(null);
  const [selection, setSelection] = useState<Selection | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [lastMove, setLastMove] = useState<{ from?: string; to?: string } | null>(null);
  const [promotionChoice, setPromotionChoice] = useState<{
    from: string;
    to: string;
    pieceType: PieceType;
  } | null>(null);
  
  // Daily puzzle state
  const [bitboardInt, setBitboardInt] = useState<number>(32539167);
  const [dailyPuzzle, setDailyPuzzle] = useState<GameState | null>(null);
  const [classicStartPosition, setClassicStartPosition] = useState<GameState | null>(null);
  const [mode, setMode] = useState<'daily' | 'classic'>('daily');
  const [puzzles, setPuzzles] = useState<api.PuzzleData[] | null>(null);

  // Get today's puzzle index (1-365 based on day of year)
  const getTodayPuzzleIndex = useCallback(() => {
    const now = new Date();
    const start = new Date(now.getFullYear(), 0, 0);
    const diff = now.getTime() - start.getTime();
    const oneDay = 1000 * 60 * 60 * 24;
    const dayOfYear = Math.floor(diff / oneDay);
    return dayOfYear; // 1-365
  }, []);

  // Load puzzles.json on mount
  useEffect(() => {
    api.loadPuzzles()
      .then(data => setPuzzles(data))
      .catch(err => console.warn('Failed to load puzzles.json:', err));
  }, []);

  // Load today's daily puzzle
  const loadDailyPuzzle = useCallback(async () => {
    setLoading(true);
    setError(null);
    setSelection(null);
    setLastMove(null);
    setMode('daily');
    
    try {
      // Get today's puzzle from pre-generated list
      if (puzzles && puzzles.length > 0) {
        const dayIndex = getTodayPuzzleIndex();
        const puzzleIndex = (dayIndex - 1) % puzzles.length;
        const todayPuzzle = puzzles[puzzleIndex];
        
        setBitboardInt(todayPuzzle.bitboard);
        
        // Load the position to get legal moves, etc.
        const gameState = await api.loadPosition(todayPuzzle.sfen);
        if (gameState.success) {
          setDailyPuzzle(gameState);
          setGame(gameState);
          setLoading(false);
          return;
        }
      }
      
      // Fallback to classic game if puzzles not loaded
      console.warn('Puzzles not loaded, falling back to classic game');
      const newGame = await api.newGame();
      setBitboardInt(32539167);
      setGame(newGame);
      setClassicStartPosition(newGame);
      setMode('classic');
    } catch (e: any) {
      console.warn('Daily puzzle failed:', e);
      try {
        const newGame = await api.newGame();
        setBitboardInt(32539167);
        setGame(newGame);
        setClassicStartPosition(newGame);
        setMode('classic');
      } catch (e2: any) {
        setError(e2.message || 'Failed to start game');
      }
    }
    setLoading(false);
  }, [puzzles, getTodayPuzzleIndex]);

  // Load classic minishogi starting position
  const loadClassicGame = useCallback(async () => {
    setLoading(true);
    setError(null);
    setSelection(null);
    setLastMove(null);
    setMode('classic');
    setBitboardInt(32539167);  // Standard position bitboard
    try {
      const newGame = await api.newGame();
      setClassicStartPosition(newGame);
      setGame(newGame);
    } catch (e: any) {
      setError(e.message || 'Failed to start game');
    }
    setLoading(false);
  }, []);

  // Reset to current mode's starting position
  const resetGame = useCallback(() => {
    setSelection(null);
    setLastMove(null);
    setError(null);
    
    if (mode === 'daily' && dailyPuzzle) {
      setGame(dailyPuzzle);
    } else if (mode === 'classic' && classicStartPosition) {
      setGame(classicStartPosition);
    } else if (mode === 'daily') {
      loadDailyPuzzle();
    } else {
      loadClassicGame();
    }
  }, [mode, dailyPuzzle, classicStartPosition, loadDailyPuzzle, loadClassicGame]);

  // Initialize game on mount - wait for puzzles to load first
  useEffect(() => {
    if (puzzles !== null) {
      loadDailyPuzzle();
    } else if (puzzles === null) {
      // Puzzles still loading, try loading after a short delay or load classic
      const timer = setTimeout(() => {
        if (!game) {
          loadClassicGame();
        }
      }, 2000);
      return () => clearTimeout(timer);
    }
  }, [puzzles, loadDailyPuzzle, loadClassicGame, game]);

  // Execute a move
  const executeMove = useCallback(async (moveStr: string, fromSquare?: string, toSquare?: string) => {
    if (!game) return;
    
    setLoading(true);
    setError(null);
    
    try {
      const afterPlayerMove = await api.makeMove(game.sfen, moveStr);
      
      if (!afterPlayerMove.success) {
        setError(afterPlayerMove.error || 'Invalid move');
        setLoading(false);
        return;
      }
      
      setLastMove({ from: fromSquare, to: toSquare });
      
      const newState: GameState = {
        sfen: afterPlayerMove.sfen!,
        side_to_move: afterPlayerMove.side_to_move!,
        legal_moves: afterPlayerMove.legal_moves!,
        is_check: afterPlayerMove.is_check!,
        result: afterPlayerMove.result!,
        hand: afterPlayerMove.hand!,
      };
      setGame(newState);
      
      // Bot's turn
      if (newState.result === 'ONGOING' && newState.side_to_move === 'WHITE') {
        const botMoveResult = await api.getBotMove(newState.sfen, 'greedy');
        
        if (botMoveResult.success && botMoveResult.move) {
          const botFrom = botMoveResult.move.includes('*') 
            ? undefined 
            : botMoveResult.move.substring(0, 2);
          const botTo = botMoveResult.move.includes('*')
            ? botMoveResult.move.substring(2, 4)
            : botMoveResult.move.substring(2, 4);
          
          const afterBotMove = await api.makeMove(newState.sfen, botMoveResult.move);
          
          if (afterBotMove.success) {
            setLastMove({ from: botFrom, to: botTo });
            setGame({
              sfen: afterBotMove.sfen!,
              side_to_move: afterBotMove.side_to_move!,
              legal_moves: afterBotMove.legal_moves!,
              is_check: afterBotMove.is_check!,
              result: afterBotMove.result!,
              hand: afterBotMove.hand!,
            });
          }
        }
      }
    } catch (e: any) {
      setError(e.message || 'Move failed');
    }
    
    setLoading(false);
  }, [game]);

  // Handle board square click
  const handleSquareClick = useCallback((notation: string) => {
    if (!game || game.side_to_move !== 'BLACK' || loading) return;
    if (game.result !== 'ONGOING') return;
    
    const pieces = parseSfenBoard(game.sfen);
    const clickedPiece = pieces.get(notation);
    
    if (selection === null) {
      if (clickedPiece && clickedPiece.color === 'BLACK') {
        setSelection({ type: 'board', square: notation });
      }
    } else if (selection.type === 'board' && selection.square) {
      if (notation === selection.square) {
        setSelection(null);
      } else if (clickedPiece && clickedPiece.color === 'BLACK') {
        setSelection({ type: 'board', square: notation });
      } else {
        const moveBase = `${selection.square}${notation}`;
        const canPromote = game.legal_moves.includes(moveBase + '+');
        const canNotPromote = game.legal_moves.includes(moveBase);
        
        if (canPromote && canNotPromote) {
          const piece = pieces.get(selection.square);
          if (piece) {
            setPromotionChoice({
              from: selection.square,
              to: notation,
              pieceType: piece.type,
            });
          }
        } else if (canPromote) {
          executeMove(moveBase + '+', selection.square, notation);
        } else if (canNotPromote) {
          executeMove(moveBase, selection.square, notation);
        }
        
        setSelection(null);
      }
    } else if (selection.type === 'hand' && selection.pieceType) {
      const dropMove = `${getPieceChar(selection.pieceType)}*${notation}`;
      
      if (game.legal_moves.includes(dropMove)) {
        executeMove(dropMove, undefined, notation);
      }
      
      setSelection(null);
    }
  }, [game, selection, loading, executeMove]);

  // Handle hand piece click
  const handleHandClick = useCallback((pieceType: PieceType, color: Color) => {
    if (!game || game.side_to_move !== color || loading) return;
    if (game.result !== 'ONGOING') return;
    if (color !== 'BLACK') return;
    
    if (selection?.type === 'hand' && selection.pieceType === pieceType) {
      setSelection(null);
    } else {
      setSelection({ type: 'hand', pieceType });
    }
  }, [game, selection, loading]);

  // Handle promotion choice
  const handlePromotionChoice = useCallback((promote: boolean) => {
    if (!promotionChoice) return;
    
    const moveStr = `${promotionChoice.from}${promotionChoice.to}${promote ? '+' : ''}`;
    executeMove(moveStr, promotionChoice.from, promotionChoice.to);
    setPromotionChoice(null);
  }, [promotionChoice, executeMove]);

  // Get legal target squares
  const getLegalTargets = useCallback((): Set<string> => {
    if (!game || !selection) return new Set();
    
    const targets = new Set<string>();
    
    if (selection.type === 'board' && selection.square) {
      game.legal_moves.forEach(move => {
        if (move.startsWith(selection.square!)) {
          targets.add(move.substring(2, 4));
        }
      });
    } else if (selection.type === 'hand' && selection.pieceType) {
      const pieceChar = getPieceChar(selection.pieceType);
      game.legal_moves.forEach(move => {
        if (move.startsWith(`${pieceChar}*`)) {
          targets.add(move.substring(2, 4));
        }
      });
    }
    
    return targets;
  }, [game, selection]);

  // Loading state
  if (!game) {
    return (
      <div className="loading">
        <div className="spinner"></div>
        <span>Loading game...</span>
      </div>
    );
  }

  const pieces = parseSfenBoard(game.sfen);
  const legalTargets = getLegalTargets();
  const isGameOver = game.result !== 'ONGOING';
  const files = [1, 2, 3, 4, 5];
  const ranks = ['a', 'b', 'c', 'd', 'e'];

  return (
    <>
      <h1>BitShogi</h1>
      <p className="subtitle">{bitboardInt}</p>

      <div className="game-container">
        {/* Left Sidebar - Opponent's hand */}
        <div className="sidebar sidebar-left">
          <div className="hand">
            <div className="hand-title">White's Hand</div>
            <div className="hand-pieces">
              {Object.keys(game.hand.WHITE).length === 0 ? (
                <span className="empty-hand">Empty</span>
              ) : (
                Object.entries(game.hand.WHITE).map(([type, count]) => (
                  <div key={type} className="hand-piece opponent">
                    <PieceImage type={type} />
                    {count > 1 && <span className="count">×{count}</span>}
                  </div>
                ))
              )}
            </div>
          </div>
        </div>

        {/* Board */}
        <div className="board-wrapper">
          <div className="board-with-coords">
            <div className="file-coords">
              {files.map(f => <span key={f}>{f}</span>)}
            </div>
            
            <div className="board-row-wrapper">
              <div className="rank-coords">
                {ranks.map(r => <span key={r} className="rank-coord">{r}</span>)}
              </div>
              
              <div className="board-container">
                <BoardLines />
                <div className="board">
                  {ranks.map((rankChar, rankIdx) => (
                    files.map(file => {
                      const notation = `${file}${rankChar}`;
                      const piece = pieces.get(notation);
                      const hasPiece = piece !== undefined;
                      const isSelected = selection?.type === 'board' && selection.square === notation;
                      const isLegalTarget = legalTargets.has(notation);
                      const isLastMoveSquare = lastMove?.from === notation || lastMove?.to === notation;
                      const isMiddleRank = rankIdx === 2; // 'c' is middle rank
                      
                      return (
                        <div
                          key={notation}
                          className={`square ${isMiddleRank ? 'rank-middle' : ''} ${hasPiece ? 'has-piece' : ''} ${isSelected ? 'selected' : ''} ${isLegalTarget ? 'legal-target' : ''} ${isLastMoveSquare ? 'last-move' : ''}`}
                          onClick={() => handleSquareClick(notation)}
                        >
                          <div className="square-dot"></div>
                          {piece && (
                            <div className={`piece ${piece.color.toLowerCase()} ${isPromoted(piece.type) ? 'promoted' : ''}`}>
                              <PieceImage type={piece.type} />
                            </div>
                          )}
                        </div>
                      );
                    })
                  )).flat()}
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Right Sidebar - Player's hand + controls */}
        <div className="sidebar sidebar-right">
          <div className="hand">
            <div className="hand-title">Your Hand</div>
            <div className="hand-pieces">
              {Object.keys(game.hand.BLACK).length === 0 ? (
                <span className="empty-hand">Empty</span>
              ) : (
                Object.entries(game.hand.BLACK).map(([type, count]) => (
                  <div
                    key={type}
                    className={`hand-piece ${selection?.type === 'hand' && selection.pieceType === type ? 'selected' : ''}`}
                    onClick={() => handleHandClick(type as PieceType, 'BLACK')}
                  >
                    <PieceImage type={type} />
                    {count > 1 && <span className="count">×{count}</span>}
                  </div>
                ))
              )}
            </div>
          </div>

          {/* Game Info */}
          <div className="game-info">
            {!isGameOver && (
              <div className="turn-indicator">
                <span className="turn-dot"></span>
                <span>{game.side_to_move === 'BLACK' ? 'Your turn' : 'Thinking...'}</span>
              </div>
            )}
            
            {game.is_check && !isGameOver && (
              <p className="status check">Check!</p>
            )}
            
            {isGameOver && (
              <p className="status game-over">
                {game.result.includes('BLACK_WIN') || game.result === 'CHECKMATE_BLACK' ? '🎉 You Win!' : 
                 game.result.includes('WHITE_WIN') || game.result === 'CHECKMATE_WHITE' ? 'Bot Wins' : 
                 'Draw'}
              </p>
            )}
            
            {error && <p className="error">{error}</p>}
            
            {loading && (
              <div className="loading">
                <div className="spinner"></div>
              </div>
            )}
            
            <div className="controls">
              <button onClick={resetGame} disabled={loading}>
                Reset
              </button>
              <button 
                onClick={loadClassicGame} 
                disabled={loading}
                className={mode === 'classic' ? 'active' : ''}
              >
                Classic
              </button>
              <button 
                onClick={loadDailyPuzzle} 
                disabled={loading}
                className={mode === 'daily' ? 'active' : ''}
              >
                Daily
              </button>
            </div>
          </div>

          <p className="help-text">
            Click a piece, then click where to move. Green dots show legal moves.
          </p>
        </div>
      </div>

      {/* Promotion Dialog */}
      {promotionChoice && (
        <div className="promotion-overlay" onClick={() => setPromotionChoice(null)}>
          <div className="promotion-dialog" onClick={e => e.stopPropagation()}>
            <h3>Promote piece?</h3>
            <div className="promotion-choices">
              <div className="promotion-choice" onClick={() => handlePromotionChoice(true)}>
                <div className="piece promoted">
                  <PieceImage type={`PROMOTED_${promotionChoice.pieceType}`} />
                </div>
              </div>
              <div className="promotion-choice" onClick={() => handlePromotionChoice(false)}>
                <div className="piece">
                  <PieceImage type={promotionChoice.pieceType} />
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Footer */}
      <footer className="footer" style={{ textAlign: 'center'}}>
        <div>
        Author: Sam Ghalayini - <a href="https://github.com/sam-ghala/BitShogi" target="_blank" rel="noopener noreferrer">Code</a>
        </div>
        <div style={{ fontSize: '0.8em', opacity: 0.8, marginTop: '4px' }}>
        playing a little bit every day using bitboards
        </div>
        {/* <div style={{ fontSize: '0.8em', opacity: 0.8, marginTop: '4px' }}>
        32539167 is the bitboard integer for the offical minishogi starting position
        </div> */}
      </footer>
    </>
  );
}

export default App;








// import { useState, useEffect, useCallback } from 'react';
// import { GameState, Piece, Selection, PieceType, Color } from './types/game';
// import * as api from './api/client';

// // Piece image paths - maps piece types to SVG filenames
// const PIECE_IMAGES: Record<string, string> = {
//   PAWN: '/pieces/pawn.svg',
//   SILVER: '/pieces/silver.svg',
//   GOLD: '/pieces/gold.svg',
//   BISHOP: '/pieces/bishop.svg',
//   ROOK: '/pieces/rook.svg',
//   KING: '/pieces/king.svg',
//   PROMOTED_PAWN: '/pieces/pawn-p.svg',
//   PROMOTED_SILVER: '/pieces/silver-p.svg',
//   PROMOTED_BISHOP: '/pieces/bishop-p.svg',
//   PROMOTED_ROOK: '/pieces/rook-p.svg',
//   // Fallbacks for standard shogi (not used in minishogi but keeping for compatibility)
//   LANCE: '/pieces/lance.svg',
//   KNIGHT: '/pieces/knight.svg',
//   PROMOTED_LANCE: '/pieces/lance-p.svg',
//   PROMOTED_KNIGHT: '/pieces/knight-p.svg',
// };

// // Fallback kanji symbols (used if SVG not found)
// const PIECE_SYMBOLS: Record<string, string> = {
//   PAWN: '歩', LANCE: '香', KNIGHT: '桂', SILVER: '銀',
//   GOLD: '金', BISHOP: '角', ROOK: '飛', KING: '王',
//   PROMOTED_PAWN: 'と', PROMOTED_LANCE: '杏', PROMOTED_KNIGHT: '圭',
//   PROMOTED_SILVER: '全', PROMOTED_BISHOP: '馬', PROMOTED_ROOK: '龍',
// };

// // Piece component - renders SVG image with fallback to kanji
// function PieceImage({ type, className }: { type: string; className?: string }) {
//   const imgSrc = PIECE_IMAGES[type];
//   const fallback = PIECE_SYMBOLS[type] || '?';
  
//   return (
//     <img 
//       src={imgSrc} 
//       alt={type}
//       className={`piece-img ${className || ''}`}
//       onError={(e) => {
//         // If SVG fails to load, replace with text fallback
//         const target = e.target as HTMLImageElement;
//         target.style.display = 'none';
//         const span = document.createElement('span');
//         span.textContent = fallback;
//         span.className = 'piece-fallback';
//         target.parentNode?.appendChild(span);
//       }}
//     />
//   );
// }

// // Parse SFEN to get board pieces
// function parseSfenBoard(sfen: string): Map<string, Piece> {
//   const pieces = new Map<string, Piece>();
//   const boardPart = sfen.split(' ')[0];
//   const ranks = boardPart.split('/');
  
//   const pieceMap: Record<string, { type: PieceType; color: Color }> = {
//     'P': { type: 'PAWN', color: 'BLACK' },
//     'L': { type: 'LANCE', color: 'BLACK' },
//     'N': { type: 'KNIGHT', color: 'BLACK' },
//     'S': { type: 'SILVER', color: 'BLACK' },
//     'G': { type: 'GOLD', color: 'BLACK' },
//     'B': { type: 'BISHOP', color: 'BLACK' },
//     'R': { type: 'ROOK', color: 'BLACK' },
//     'K': { type: 'KING', color: 'BLACK' },
//     'p': { type: 'PAWN', color: 'WHITE' },
//     'l': { type: 'LANCE', color: 'WHITE' },
//     'n': { type: 'KNIGHT', color: 'WHITE' },
//     's': { type: 'SILVER', color: 'WHITE' },
//     'g': { type: 'GOLD', color: 'WHITE' },
//     'b': { type: 'BISHOP', color: 'WHITE' },
//     'r': { type: 'ROOK', color: 'WHITE' },
//     'k': { type: 'KING', color: 'WHITE' },
//   };
  
//   const promotedMap: Record<string, PieceType> = {
//     'P': 'PROMOTED_PAWN', 'L': 'PROMOTED_LANCE', 'N': 'PROMOTED_KNIGHT',
//     'S': 'PROMOTED_SILVER', 'B': 'PROMOTED_BISHOP', 'R': 'PROMOTED_ROOK',
//     'p': 'PROMOTED_PAWN', 'l': 'PROMOTED_LANCE', 'n': 'PROMOTED_KNIGHT',
//     's': 'PROMOTED_SILVER', 'b': 'PROMOTED_BISHOP', 'r': 'PROMOTED_ROOK',
//   };
  
//   ranks.forEach((rankStr, rankIdx) => {
//     const rank = rankIdx + 1;
//     let file = 1;
//     let nextIsPromoted = false;
    
//     for (const char of rankStr) {
//       if (char === '+') {
//         nextIsPromoted = true;
//         continue;
//       }
      
//       if (/\d/.test(char)) {
//         file += parseInt(char);
//         nextIsPromoted = false;
//         continue;
//       }
      
//       const pieceInfo = pieceMap[char];
//       if (pieceInfo) {
//         const notation = `${file}${String.fromCharCode(96 + rank)}`;
//         const type = nextIsPromoted ? promotedMap[char] : pieceInfo.type;
//         pieces.set(notation, { type, color: pieceInfo.color });
//         file++;
//         nextIsPromoted = false;
//       }
//     }
//   });
  
//   return pieces;
// }

// // Get piece char for drop move notation
// function getPieceChar(type: PieceType): string {
//   const map: Record<string, string> = {
//     PAWN: 'P', LANCE: 'L', KNIGHT: 'N', SILVER: 'S',
//     GOLD: 'G', BISHOP: 'B', ROOK: 'R',
//   };
//   return map[type] || '?';
// }

// // Check if a piece type is promoted
// function isPromoted(type: PieceType): boolean {
//   return type.startsWith('PROMOTED_');
// }

// // SVG Board Lines Component
// function BoardLines() {
//   const size = 64;
//   const lines: JSX.Element[] = [];
  
//   for (let row = 0; row < 5; row++) {
//     for (let col = 0; col < 5; col++) {
//       const cx = col * size + size / 2;
//       const cy = row * size + size / 2;
      
//       // Horizontal line (right)
//       if (col < 4) {
//         lines.push(
//           <line key={`h-${row}-${col}`} x1={cx} y1={cy} x2={cx + size} y2={cy} />
//         );
//       }
//       // Vertical line (down)
//       if (row < 4) {
//         lines.push(
//           <line key={`v-${row}-${col}`} x1={cx} y1={cy} x2={cx} y2={cy + size} />
//         );
//       }
//       // Diagonal down-right
//       if (col < 4 && row < 4) {
//         lines.push(
//           <line key={`dr-${row}-${col}`} x1={cx} y1={cy} x2={cx + size} y2={cy + size} />
//         );
//       }
//       // Diagonal down-left
//       if (col > 0 && row < 4) {
//         lines.push(
//           <line key={`dl-${row}-${col}`} x1={cx} y1={cy} x2={cx - size} y2={cy + size} />
//         );
//       }
//     }
//   }
  
//   return (
//     <svg className="board-lines" width={5 * size} height={5 * size}>
//       {lines}
//     </svg>
//   );
// }

// function App() {
//   const [game, setGame] = useState<GameState | null>(null);
//   const [selection, setSelection] = useState<Selection | null>(null);
//   const [loading, setLoading] = useState(false);
//   const [error, setError] = useState<string | null>(null);
//   const [lastMove, setLastMove] = useState<{ from?: string; to?: string } | null>(null);
//   const [promotionChoice, setPromotionChoice] = useState<{
//     from: string;
//     to: string;
//     pieceType: PieceType;
//   } | null>(null);
  
//   // Daily puzzle state
//   const [bitboardInt, setBitboardInt] = useState<number>(32539167);
//   const [dailyPuzzle, setDailyPuzzle] = useState<GameState | null>(null);
//   const [classicStartPosition, setClassicStartPosition] = useState<GameState | null>(null);
//   const [mode, setMode] = useState<'daily' | 'classic'>('daily');

//   // Load today's daily puzzle
//   const loadDailyPuzzle = useCallback(async () => {
//     setLoading(true);
//     setError(null);
//     setSelection(null);
//     setLastMove(null);
//     setMode('daily');
//     try {
//       const puzzle = await api.getDailyPuzzle();
//       setBitboardInt(puzzle.bitboard_int);
//       setDailyPuzzle(puzzle);
//       setGame(puzzle);
//     } catch (e: any) {
//       // Fallback to regular new game if daily puzzle fails
//       console.warn('Daily puzzle failed, falling back to standard game:', e);
//       try {
//         const newGame = await api.newGame();
//         setBitboardInt(32539167);
//         setGame(newGame);
//         setClassicStartPosition(newGame);
//         setMode('classic');
//       } catch (e2: any) {
//         setError(e2.message || 'Failed to start game');
//       }
//     }
//     setLoading(false);
//   }, []);

//   // Load classic minishogi starting position
//   const loadClassicGame = useCallback(async () => {
//     setLoading(true);
//     setError(null);
//     setSelection(null);
//     setLastMove(null);
//     setMode('classic');
//     setBitboardInt(32539167);  // Standard position bitboard
//     try {
//       const newGame = await api.newGame();
//       setClassicStartPosition(newGame);
//       setGame(newGame);
//     } catch (e: any) {
//       setError(e.message || 'Failed to start game');
//     }
//     setLoading(false);
//   }, []);

//   // Reset to current mode's starting position
//   const resetGame = useCallback(() => {
//     setSelection(null);
//     setLastMove(null);
//     setError(null);
    
//     if (mode === 'daily' && dailyPuzzle) {
//       setGame(dailyPuzzle);
//     } else if (mode === 'classic' && classicStartPosition) {
//       setGame(classicStartPosition);
//     } else if (mode === 'daily') {
//       loadDailyPuzzle();
//     } else {
//       loadClassicGame();
//     }
//   }, [mode, dailyPuzzle, classicStartPosition, loadDailyPuzzle, loadClassicGame]);

//   // Initialize game on mount
//   useEffect(() => {
//     loadDailyPuzzle();
//   }, [loadDailyPuzzle]);

//   // Execute a move
//   const executeMove = useCallback(async (moveStr: string, fromSquare?: string, toSquare?: string) => {
//     if (!game) return;
    
//     setLoading(true);
//     setError(null);
    
//     try {
//       const afterPlayerMove = await api.makeMove(game.sfen, moveStr);
      
//       if (!afterPlayerMove.success) {
//         setError(afterPlayerMove.error || 'Invalid move');
//         setLoading(false);
//         return;
//       }
      
//       setLastMove({ from: fromSquare, to: toSquare });
      
//       const newState: GameState = {
//         sfen: afterPlayerMove.sfen!,
//         side_to_move: afterPlayerMove.side_to_move!,
//         legal_moves: afterPlayerMove.legal_moves!,
//         is_check: afterPlayerMove.is_check!,
//         result: afterPlayerMove.result!,
//         hand: afterPlayerMove.hand!,
//       };
//       setGame(newState);
      
//       // Bot's turn
//       if (newState.result === 'ONGOING' && newState.side_to_move === 'WHITE') {
//         const botMoveResult = await api.getBotMove(newState.sfen, 'greedy');
        
//         if (botMoveResult.success && botMoveResult.move) {
//           const botFrom = botMoveResult.move.includes('*') 
//             ? undefined 
//             : botMoveResult.move.substring(0, 2);
//           const botTo = botMoveResult.move.includes('*')
//             ? botMoveResult.move.substring(2, 4)
//             : botMoveResult.move.substring(2, 4);
          
//           const afterBotMove = await api.makeMove(newState.sfen, botMoveResult.move);
          
//           if (afterBotMove.success) {
//             setLastMove({ from: botFrom, to: botTo });
//             setGame({
//               sfen: afterBotMove.sfen!,
//               side_to_move: afterBotMove.side_to_move!,
//               legal_moves: afterBotMove.legal_moves!,
//               is_check: afterBotMove.is_check!,
//               result: afterBotMove.result!,
//               hand: afterBotMove.hand!,
//             });
//           }
//         }
//       }
//     } catch (e: any) {
//       setError(e.message || 'Move failed');
//     }
    
//     setLoading(false);
//   }, [game]);

//   // Handle board square click
//   const handleSquareClick = useCallback((notation: string) => {
//     if (!game || game.side_to_move !== 'BLACK' || loading) return;
//     if (game.result !== 'ONGOING') return;
    
//     const pieces = parseSfenBoard(game.sfen);
//     const clickedPiece = pieces.get(notation);
    
//     if (selection === null) {
//       if (clickedPiece && clickedPiece.color === 'BLACK') {
//         setSelection({ type: 'board', square: notation });
//       }
//     } else if (selection.type === 'board' && selection.square) {
//       if (notation === selection.square) {
//         setSelection(null);
//       } else if (clickedPiece && clickedPiece.color === 'BLACK') {
//         setSelection({ type: 'board', square: notation });
//       } else {
//         const moveBase = `${selection.square}${notation}`;
//         const canPromote = game.legal_moves.includes(moveBase + '+');
//         const canNotPromote = game.legal_moves.includes(moveBase);
        
//         if (canPromote && canNotPromote) {
//           const piece = pieces.get(selection.square);
//           if (piece) {
//             setPromotionChoice({
//               from: selection.square,
//               to: notation,
//               pieceType: piece.type,
//             });
//           }
//         } else if (canPromote) {
//           executeMove(moveBase + '+', selection.square, notation);
//         } else if (canNotPromote) {
//           executeMove(moveBase, selection.square, notation);
//         }
        
//         setSelection(null);
//       }
//     } else if (selection.type === 'hand' && selection.pieceType) {
//       const dropMove = `${getPieceChar(selection.pieceType)}*${notation}`;
      
//       if (game.legal_moves.includes(dropMove)) {
//         executeMove(dropMove, undefined, notation);
//       }
      
//       setSelection(null);
//     }
//   }, [game, selection, loading, executeMove]);

//   // Handle hand piece click
//   const handleHandClick = useCallback((pieceType: PieceType, color: Color) => {
//     if (!game || game.side_to_move !== color || loading) return;
//     if (game.result !== 'ONGOING') return;
//     if (color !== 'BLACK') return;
    
//     if (selection?.type === 'hand' && selection.pieceType === pieceType) {
//       setSelection(null);
//     } else {
//       setSelection({ type: 'hand', pieceType });
//     }
//   }, [game, selection, loading]);

//   // Handle promotion choice
//   const handlePromotionChoice = useCallback((promote: boolean) => {
//     if (!promotionChoice) return;
    
//     const moveStr = `${promotionChoice.from}${promotionChoice.to}${promote ? '+' : ''}`;
//     executeMove(moveStr, promotionChoice.from, promotionChoice.to);
//     setPromotionChoice(null);
//   }, [promotionChoice, executeMove]);

//   // Get legal target squares
//   const getLegalTargets = useCallback((): Set<string> => {
//     if (!game || !selection) return new Set();
    
//     const targets = new Set<string>();
    
//     if (selection.type === 'board' && selection.square) {
//       game.legal_moves.forEach(move => {
//         if (move.startsWith(selection.square!)) {
//           targets.add(move.substring(2, 4));
//         }
//       });
//     } else if (selection.type === 'hand' && selection.pieceType) {
//       const pieceChar = getPieceChar(selection.pieceType);
//       game.legal_moves.forEach(move => {
//         if (move.startsWith(`${pieceChar}*`)) {
//           targets.add(move.substring(2, 4));
//         }
//       });
//     }
    
//     return targets;
//   }, [game, selection]);

//   // Loading state
//   if (!game) {
//     return (
//       <div className="loading">
//         <div className="spinner"></div>
//         <span>Loading game...</span>
//       </div>
//     );
//   }

//   const pieces = parseSfenBoard(game.sfen);
//   const legalTargets = getLegalTargets();
//   const isGameOver = game.result !== 'ONGOING';
//   const files = [1, 2, 3, 4, 5];
//   const ranks = ['a', 'b', 'c', 'd', 'e'];

//   return (
//     <>
//       <h1>BitShogi</h1>
//       <p className="subtitle">{bitboardInt}</p>
//       {/* <p className="subtitle">BitShogi {mode === 'daily' ? '• Daily Puzzle' : '• Classic'}</p> */}
      
//       <div className="game-container">
//         {/* Left Sidebar - Opponent's hand */}
//         <div className="sidebar sidebar-left">
//           <div className="hand">
//             <div className="hand-title">White's Hand</div>
//             <div className="hand-pieces">
//               {Object.keys(game.hand.WHITE).length === 0 ? (
//                 <span className="empty-hand">Empty</span>
//               ) : (
//                 Object.entries(game.hand.WHITE).map(([type, count]) => (
//                   <div key={type} className="hand-piece opponent">
//                     <PieceImage type={type} />
//                     {count > 1 && <span className="count">×{count}</span>}
//                   </div>
//                 ))
//               )}
//             </div>
//           </div>
//         </div>

//         {/* Board */}
//         <div className="board-wrapper">
//           <div className="board-with-coords">
//             <div className="file-coords">
//               {files.map(f => <span key={f}>{f}</span>)}
//             </div>
            
//             <div className="board-row-wrapper">
//               <div className="rank-coords">
//                 {ranks.map(r => <span key={r} className="rank-coord">{r}</span>)}
//               </div>
              
//               <div className="board-container">
//                 <BoardLines />
//                 <div className="board">
//                   {ranks.map((rankChar, rankIdx) => (
//                     files.map(file => {
//                       const notation = `${file}${rankChar}`;
//                       const piece = pieces.get(notation);
//                       const hasPiece = piece !== undefined;
//                       const isSelected = selection?.type === 'board' && selection.square === notation;
//                       const isLegalTarget = legalTargets.has(notation);
//                       const isLastMoveSquare = lastMove?.from === notation || lastMove?.to === notation;
//                       const isMiddleRank = rankIdx === 2; // 'c' is middle rank
                      
//                       return (
//                         <div
//                           key={notation}
//                           className={`square ${isMiddleRank ? 'rank-middle' : ''} ${hasPiece ? 'has-piece' : ''} ${isSelected ? 'selected' : ''} ${isLegalTarget ? 'legal-target' : ''} ${isLastMoveSquare ? 'last-move' : ''}`}
//                           onClick={() => handleSquareClick(notation)}
//                         >
//                           <div className="square-dot"></div>
//                           {piece && (
//                             <div className={`piece ${piece.color.toLowerCase()} ${isPromoted(piece.type) ? 'promoted' : ''}`}>
//                               <PieceImage type={piece.type} />
//                             </div>
//                           )}
//                         </div>
//                       );
//                     })
//                   )).flat()}
//                 </div>
//               </div>
//             </div>
//           </div>
//         </div>

//         {/* Right Sidebar - Player's hand + controls */}
//         <div className="sidebar sidebar-right">
//           <div className="hand">
//             <div className="hand-title">Your Hand</div>
//             <div className="hand-pieces">
//               {Object.keys(game.hand.BLACK).length === 0 ? (
//                 <span className="empty-hand">Empty</span>
//               ) : (
//                 Object.entries(game.hand.BLACK).map(([type, count]) => (
//                   <div
//                     key={type}
//                     className={`hand-piece ${selection?.type === 'hand' && selection.pieceType === type ? 'selected' : ''}`}
//                     onClick={() => handleHandClick(type as PieceType, 'BLACK')}
//                   >
//                     <PieceImage type={type} />
//                     {count > 1 && <span className="count">×{count}</span>}
//                   </div>
//                 ))
//               )}
//             </div>
//           </div>

//           {/* Game Info */}
//           <div className="game-info">
//             {!isGameOver && (
//               <div className="turn-indicator">
//                 <span className="turn-dot"></span>
//                 <span>{game.side_to_move === 'BLACK' ? 'Your turn' : 'Thinking...'}</span>
//               </div>
//             )}
            
//             {game.is_check && !isGameOver && (
//               <p className="status check">Check!</p>
//             )}
            
//             {isGameOver && (
//               <p className="status game-over">
//                 {game.result.includes('BLACK') ? '🎉 You Win!' : 
//                  game.result.includes('WHITE') ? 'Bot Wins' : 
//                  'Draw'}
//               </p>
//             )}
            
//             {error && <p className="error">{error}</p>}
            
//             {loading && (
//               <div className="loading">
//                 <div className="spinner"></div>
//               </div>
//             )}
            
//             <div className="controls">
//               <button onClick={resetGame} disabled={loading}>
//                 Reset
//               </button>
//               <button 
//                 onClick={loadClassicGame} 
//                 disabled={loading}
//                 className={mode === 'classic' ? 'active' : ''}
//               >
//                 Classic
//               </button>
//               <button 
//                 onClick={loadDailyPuzzle} 
//                 disabled={loading}
//                 className={mode === 'daily' ? 'active' : ''}
//               >
//                 Daily
//               </button>
//             </div>
//           </div>

//           <p className="help-text">
//             Click a piece, then click where to move. Green dots show legal moves.
//           </p>
//         </div>
//       </div>

//       {/* Promotion Dialog */}
//       {promotionChoice && (
//         <div className="promotion-overlay" onClick={() => setPromotionChoice(null)}>
//           <div className="promotion-dialog" onClick={e => e.stopPropagation()}>
//             <h3>Promote piece?</h3>
//             <div className="promotion-choices">
//               <div className="promotion-choice" onClick={() => handlePromotionChoice(true)}>
//                 <div className="piece promoted">
//                   <PieceImage type={`PROMOTED_${promotionChoice.pieceType}`} />
//                 </div>
//               </div>
//               <div className="promotion-choice" onClick={() => handlePromotionChoice(false)}>
//                 <div className="piece">
//                   <PieceImage type={promotionChoice.pieceType} />
//                 </div>
//               </div>
//             </div>
//           </div>
//         </div>
//       )}

//       <footer className="footer" style={{ textAlign: 'center'}}>
//         <div>
//         Author: Sam Ghalayini - <a href="https://github.com/sam-ghala/BitShogi" target="_blank" rel="noopener noreferrer">Code</a>
//         </div>
//         <div style={{ fontSize: '0.8em', opacity: 0.8, marginTop: '4px' }}>
//         playing a little bit every day using bitboards
//         </div>
//         {/* <div style={{ fontSize: '0.8em', opacity: 0.8, marginTop: '4px' }}>
//         32539167 is the bitboard integer for the offical minishogi starting position
//         </div> */}
//       </footer>
//     </>
//   );
// }

// export default App;



import { GameState, MoveResponse, BotMoveResponse } from '../types/game';

const API_BASE = import.meta.env.VITE_API_URL || '/api';

async function fetchJson<T>(url: string, options?: RequestInit): Promise<T> {
  const response = await fetch(url, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...options?.headers,
    },
  });
  
  if (!response.ok) {
    const error = await response.json().catch(() => ({ error: 'Request failed' }));
    throw new Error(error.error || error.detail || 'Request failed');
  }
  
  return response.json();
}

export async function newGame(): Promise<GameState> {
  return fetchJson<GameState>(`${API_BASE}/game/new`);
}

export async function makeMove(sfen: string, move: string): Promise<MoveResponse> {
  return fetchJson<MoveResponse>(`${API_BASE}/game/move`, {
    method: 'POST',
    body: JSON.stringify({ sfen, move }),
  });
}

export async function getBotMove(sfen: string, botType: string = 'greedy'): Promise<BotMoveResponse> {
  return fetchJson<BotMoveResponse>(`${API_BASE}/game/bot-move`, {
    method: 'POST',
    body: JSON.stringify({ sfen, bot_type: botType }),
  });
}

export async function getLegalMoves(sfen: string): Promise<{ moves: string[]; count: number }> {
  return fetchJson(`${API_BASE}/game/legal-moves?sfen=${encodeURIComponent(sfen)}`);
}

export async function loadPosition(sfen: string): Promise<GameState & { success: boolean }> {
  return fetchJson(`${API_BASE}/game/load`, {
    method: 'POST',
    body: JSON.stringify({ sfen }),
  });
}

export interface PuzzleData {
  day: number;
  sfen: string;
  bitboard: number;
}

export async function loadPuzzles(): Promise<PuzzleData[]> {
  const response = await fetch('/puzzles.json');
  if (!response.ok) {
    throw new Error('Failed to load puzzles');
  }
  return response.json();
}