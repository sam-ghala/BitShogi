import { useState, useEffect, useCallback } from 'react';
import { GameState, Piece, Selection, PieceType, Color } from './types/game';
import * as api from './api/client';

// Piece symbols (Kanji)
const PIECE_SYMBOLS: Record<string, string> = {
  PAWN: '歩', LANCE: '香', KNIGHT: '桂', SILVER: '銀',
  GOLD: '金', BISHOP: '角', ROOK: '飛', KING: '王',
  PROMOTED_PAWN: 'と', PROMOTED_LANCE: '杏', PROMOTED_KNIGHT: '圭',
  PROMOTED_SILVER: '全', PROMOTED_BISHOP: '馬', PROMOTED_ROOK: '龍',
};

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

  // Start new game
  const startNewGame = useCallback(async () => {
    setLoading(true);
    setError(null);
    setSelection(null);
    setLastMove(null);
    try {
      const newGame = await api.newGame();
      setGame(newGame);
    } catch (e: any) {
      setError(e.message || 'Failed to start game');
    }
    setLoading(false);
  }, []);

  // Initialize game on mount
  useEffect(() => {
    startNewGame();
  }, [startNewGame]);

  // Execute a move
  const executeMove = useCallback(async (moveStr: string, fromSquare?: string, toSquare?: string) => {
    if (!game) return;
    
    setLoading(true);
    setError(null);
    
    try {
      // Make player move
      const afterPlayerMove = await api.makeMove(game.sfen, moveStr);
      
      if (!afterPlayerMove.success) {
        setError(afterPlayerMove.error || 'Invalid move');
        setLoading(false);
        return;
      }
      
      setLastMove({ from: fromSquare, to: toSquare });
      
      // Update game state
      const newState: GameState = {
        sfen: afterPlayerMove.sfen!,
        side_to_move: afterPlayerMove.side_to_move!,
        legal_moves: afterPlayerMove.legal_moves!,
        is_check: afterPlayerMove.is_check!,
        result: afterPlayerMove.result!,
        hand: afterPlayerMove.hand!,
      };
      setGame(newState);
      
      // If game not over and it's bot's turn (WHITE), get bot move
      if (newState.result === 'ONGOING' && newState.side_to_move === 'WHITE') {
        const botMoveResult = await api.getBotMove(newState.sfen, 'greedy');
        
        if (botMoveResult.success && botMoveResult.move) {
          // Parse bot move for highlighting
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
      // First click - select a piece
      if (clickedPiece && clickedPiece.color === 'BLACK') {
        setSelection({ type: 'board', square: notation });
      }
    } else if (selection.type === 'board' && selection.square) {
      // Second click with board piece selected
      if (notation === selection.square) {
        // Clicked same square - deselect
        setSelection(null);
      } else if (clickedPiece && clickedPiece.color === 'BLACK') {
        // Clicked another own piece - switch selection
        setSelection({ type: 'board', square: notation });
      } else {
        // Try to move
        const moveBase = `${selection.square}${notation}`;
        const canPromote = game.legal_moves.includes(moveBase + '+');
        const canNotPromote = game.legal_moves.includes(moveBase);
        
        if (canPromote && canNotPromote) {
          // Ask for promotion choice
          const piece = pieces.get(selection.square);
          if (piece) {
            setPromotionChoice({
              from: selection.square,
              to: notation,
              pieceType: piece.type,
            });
          }
        } else if (canPromote) {
          // Must promote
          executeMove(moveBase + '+', selection.square, notation);
        } else if (canNotPromote) {
          // Regular move
          executeMove(moveBase, selection.square, notation);
        }
        
        setSelection(null);
      }
    } else if (selection.type === 'hand' && selection.pieceType) {
      // Drop move from hand
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
    if (color !== 'BLACK') return; // Only player can select hand pieces
    
    if (selection?.type === 'hand' && selection.pieceType === pieceType) {
      // Deselect
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

  // Get legal target squares for current selection
  const getLegalTargets = useCallback((): Set<string> => {
    if (!game || !selection) return new Set();
    
    const targets = new Set<string>();
    
    if (selection.type === 'board' && selection.square) {
      game.legal_moves.forEach(move => {
        if (move.startsWith(selection.square!)) {
          const dest = move.substring(2, 4);
          targets.add(dest);
        }
      });
    } else if (selection.type === 'hand' && selection.pieceType) {
      const pieceChar = getPieceChar(selection.pieceType);
      game.legal_moves.forEach(move => {
        if (move.startsWith(`${pieceChar}*`)) {
          const dest = move.substring(2, 4);
          targets.add(dest);
        }
      });
    }
    
    return targets;
  }, [game, selection]);

  // Render loading state
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

  return (
    <>
      <h1>将棋</h1>
      <p className="subtitle">Minishogi</p>
      
      <div className="game-container">
        {/* Opponent's hand (WHITE - top) */}
        <div className="hands-container">
          <div className="hand">
            <div className="hand-title">White's Hand</div>
            <div className="hand-pieces">
              {Object.keys(game.hand.WHITE).length === 0 ? (
                <span className="empty-hand">Empty</span>
              ) : (
                Object.entries(game.hand.WHITE).map(([type, count]) => (
                  <div key={type} className="hand-piece white-hand">
                    <span className="piece white">{PIECE_SYMBOLS[type]}</span>
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
            <div></div>
            <div className="file-coords">
              {[1, 2, 3, 4, 5].map(f => <span key={f}>{f}</span>)}
            </div>
            <div className="rank-coords">
              {['a', 'b', 'c', 'd', 'e'].map(r => <span key={r}>{r}</span>)}
            </div>
            <div className="board">
              {[1, 2, 3, 4, 5].map(rank => (
                [1, 2, 3, 4, 5].map(file => {
                  const notation = `${file}${String.fromCharCode(96 + rank)}`;
                  const piece = pieces.get(notation);
                  const isSelected = selection?.type === 'board' && selection.square === notation;
                  const isLegalTarget = legalTargets.has(notation);
                  const isLastMoveSquare = lastMove?.from === notation || lastMove?.to === notation;
                  
                  return (
                    <div
                      key={notation}
                      className={`square ${isSelected ? 'selected' : ''} ${isLegalTarget ? 'legal-target' : ''} ${isLastMoveSquare ? 'last-move' : ''}`}
                      onClick={() => handleSquareClick(notation)}
                    >
                      {piece && (
                        <span className={`piece ${piece.color.toLowerCase()} ${isPromoted(piece.type) ? 'promoted' : ''}`}>
                          {PIECE_SYMBOLS[piece.type]}
                        </span>
                      )}
                    </div>
                  );
                })
              )).flat()}
            </div>
          </div>
        </div>

        {/* Player's hand (BLACK - bottom) */}
        <div className="hands-container">
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
                    <span className="piece black">{PIECE_SYMBOLS[type]}</span>
                    {count > 1 && <span className="count">×{count}</span>}
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Game Info */}
      <div className="game-info">
        {!isGameOver && (
          <div className="turn-indicator">
            <span className="turn-dot"></span>
            <span>{game.side_to_move === 'BLACK' ? 'Your turn' : 'Bot thinking...'}</span>
          </div>
        )}
        
        {game.is_check && !isGameOver && (
          <p className="status check">Check!</p>
        )}
        
        {isGameOver && (
          <p className="status game-over">
            {game.result.includes('BLACK') ? '🎉 You Win!' : 
             game.result.includes('WHITE') ? 'Bot Wins' : 
             'Draw'}
          </p>
        )}
        
        {error && <p className="error">{error}</p>}
        
        {loading && (
          <div className="loading">
            <div className="spinner"></div>
          </div>
        )}
      </div>

      {/* Controls */}
      <div className="controls">
        <button onClick={startNewGame} disabled={loading}>
          New Game
        </button>
      </div>

      {/* Help Text */}
      <p className="help-text">
        Click a piece to select it, then click a destination to move.
        Click pieces in your hand to drop them on the board.
        Green dots show legal moves.
      </p>

      {/* Promotion Dialog */}
      {promotionChoice && (
        <div className="promotion-overlay" onClick={() => setPromotionChoice(null)}>
          <div className="promotion-dialog" onClick={e => e.stopPropagation()}>
            <h3>Promote piece?</h3>
            <div className="promotion-choices">
              <div className="promotion-choice" onClick={() => handlePromotionChoice(true)}>
                <span className="piece black promoted">
                  {PIECE_SYMBOLS[`PROMOTED_${promotionChoice.pieceType}`] || '?'}
                </span>
              </div>
              <div className="promotion-choice" onClick={() => handlePromotionChoice(false)}>
                <span className="piece black">
                  {PIECE_SYMBOLS[promotionChoice.pieceType]}
                </span>
              </div>
            </div>
          </div>
        </div>
      )}
    </>
  );
}

export default App;
