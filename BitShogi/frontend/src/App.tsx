import { useState, useCallback, useEffect, useMemo } from 'react';
import { Link } from 'react-router-dom';
import { Analytics } from "@vercel/analytics/react"
import './index.css';
import * as api from './api/client';

// SVG piece paths - custom pieces in public/pieces/
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
  // Fallback for standard shogi pieces not in minishogi
  LANCE: '/pieces/lance.svg',
  KNIGHT: '/pieces/knight.svg',
  PROMOTED_LANCE: '/pieces/lance-p.svg',
  PROMOTED_KNIGHT: '/pieces/knight-p.svg',
};

// Fallback kanji symbols
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

// Get piece character for drop notation
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

// Determine game result display
function getResultDisplay(result: string, sideToMove: string): { text: string; isWin: boolean } {
  // Debug log to see actual result value
  console.log('Game result:', result, 'Side to move:', sideToMove);
  
  const resultUpper = result.toUpperCase().trim();
  
  // Check various win conditions for BLACK (human player)
  // If WHITE is in checkmate or BLACK wins
  if (resultUpper.includes('BLACK_WIN') || 
      resultUpper.includes('BLACKWIN')) {
    return { text: 'You Win!', isWin: true };
  }
  
  // Check various win conditions for WHITE (bot)
  if (resultUpper.includes('WHITE_WIN') || 
      resultUpper.includes('WHITEWIN')) {
    return { text: 'Bot Wins', isWin: false };
  }
  
  // Any result containing CHECKMATE or just MATE - determine winner by side to move
  // When checkmate happens, the side to move is the one who is checkmated
  if (resultUpper.includes('CHECKMATE') || resultUpper.includes('MATE')) {
    // Check if result specifies the winner
    if (resultUpper.includes('WHITE') || resultUpper.includes('W_')) {
      // WHITE is checkmated, BLACK wins
      return { text: 'You Win!', isWin: true };
    }
    if (resultUpper.includes('BLACK') || resultUpper.includes('B_')) {
      // BLACK is checkmated, WHITE wins
      return { text: 'Bot Wins', isWin: false };
    }
    // Generic checkmate - determine by side to move
    // The side to move when checkmated is the loser
    if (sideToMove === 'WHITE') {
      return { text: 'You Win!', isWin: true };
    } else {
      return { text: 'Bot Wins', isWin: false };
    }
  }
  
  // Stalemate (no legal moves but not in check) - this is a draw
  if (resultUpper.includes('STALEMATE')) {
    return { text: 'Draw (Stalemate)', isWin: false };
  }
  
  // Explicit draw
  if (resultUpper.includes('DRAW')) {
    return { text: 'Draw', isWin: false };
  }
  
  // Fallback - show the actual result so we can debug
  console.warn('Unknown game result:', result);
  return { text: `Game Over: ${result}`, isWin: false };
}

// Types
type PieceType = 'PAWN' | 'LANCE' | 'KNIGHT' | 'SILVER' | 'GOLD' | 'BISHOP' | 'ROOK' | 'KING' |
                 'PROMOTED_PAWN' | 'PROMOTED_LANCE' | 'PROMOTED_KNIGHT' | 'PROMOTED_SILVER' |
                 'PROMOTED_BISHOP' | 'PROMOTED_ROOK';
type Color = 'BLACK' | 'WHITE';
type BotType = 'random' | 'greedy' | 'simple';

interface Piece {
  type: PieceType;
  color: Color;
}

interface Selection {
  type: 'board' | 'hand';
  square?: string;
  pieceType?: PieceType;
}

interface GameState {
  sfen: string;
  side_to_move: Color;
  legal_moves: string[];
  is_check: boolean;
  result: string;
  hand: {
    BLACK: Record<string, number>;
    WHITE: Record<string, number>;
  };
}

// SVG Board Lines Component - uses viewBox for responsive scaling
function BoardLines() {
  const size = 64;
  const totalSize = 5 * size;
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
    <svg 
      className="board-lines" 
      viewBox={`0 0 ${totalSize} ${totalSize}`}
      preserveAspectRatio="none"
    >
      {lines}
    </svg>
  );
}

// Available bots with display names
const BOT_OPTIONS: { value: BotType; label: string }[] = [
  { value: 'random', label: 'Random' },
  { value: 'greedy', label: 'Greedy' },
  { value: 'simple', label: 'Simple' },
];

function App() {
  const [game, setGame] = useState<GameState | null>(null);
  const [selection, setSelection] = useState<Selection | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [customSfen, setCustomSfen] = useState<string>('');
  const [lastMove, setLastMove] = useState<{ from?: string; to?: string } | null>(null);
  const [promotionChoice, setPromotionChoice] = useState<{
    from: string;
    to: string;
    pieceType: PieceType;
  } | null>(null);
  
  // Daily puzzle state
  const [bitboardInt, setBitboardInt] = useState<number>(32539167);
  const [dailyPuzzle, setDailyPuzzle] = useState<GameState | null>(null);
  const [randomPuzzle, setRandomPuzzle] = useState<GameState | null>(null);
  const [classicStartPosition, setClassicStartPosition] = useState<GameState | null>(null);
  const [mode, setMode] = useState<'daily' | 'classic' | 'random'>('daily');
  const [puzzles, setPuzzles] = useState<api.PuzzleData[] | null>(null);
  const [initialized, setInitialized] = useState(false);
  
  // Bot selection state
  const [selectedBot, setSelectedBot] = useState<BotType>('greedy');

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

  // Load a random puzzle from the list
  const loadRandomPuzzle = useCallback(async () => {
    setLoading(true);
    setError(null);
    setSelection(null);
    setLastMove(null);
    setMode('random');
    
    try {
      if (puzzles && puzzles.length > 0) {
        // Pick a random puzzle
        const randomIndex = Math.floor(Math.random() * puzzles.length);
        const puzzle = puzzles[randomIndex];
        
        setBitboardInt(puzzle.bitboard);
        
        // Load the position to get legal moves, etc.
        const gameState = await api.loadPosition(puzzle.sfen);
        if (gameState.success) {
          setRandomPuzzle(gameState);
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
      console.warn('Random puzzle failed:', e);
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
  }, [puzzles]);

  // call it from the console 
  (window as any).loadRandomPuzzle = loadRandomPuzzle;

  // Load a custom SFEN position
  const loadCustomPosition = useCallback(async () => {
    if (!customSfen.trim()) return;
    
    setLoading(true);
    setError(null);
    setSelection(null);
    setLastMove(null);
    setMode('random'); // reuse random mode for custom
    
    try {
      const gameState = await api.loadPosition(customSfen.trim());
      if (gameState.success) {
        setBitboardInt(0); // no bitboard for custom
        setGame(gameState);
      } else {
        setError('Invalid SFEN format');
      }
    } catch (e: any) {
      setError(e.message || 'Failed to load position');
    }
    setLoading(false);
  }, [customSfen]);

  // Reset to current mode's starting position
  const resetGame = useCallback(() => {
    setSelection(null);
    setLastMove(null);
    setError(null);
    
    if (mode === 'daily' && dailyPuzzle) {
      setGame(dailyPuzzle);
    } else if (mode === 'classic' && classicStartPosition) {
      setGame(classicStartPosition);
    } else if (mode === 'random' && randomPuzzle) {
      setGame(randomPuzzle);
    } else if (mode === 'daily') {
      loadDailyPuzzle();
    } else if (mode === 'random') {
      loadRandomPuzzle();
    } else {
      loadClassicGame();
    }
  }, [mode, dailyPuzzle, classicStartPosition, randomPuzzle, loadDailyPuzzle, loadClassicGame, loadRandomPuzzle]);

  // Handle bot change - reset game when bot changes
  const handleBotChange = useCallback((newBot: BotType) => {
    setSelectedBot(newBot);
    // Reset to starting position when bot changes
    setSelection(null);
    setLastMove(null);
    setError(null);
    
    if (mode === 'daily' && dailyPuzzle) {
      setGame(dailyPuzzle);
    } else if (mode === 'classic' && classicStartPosition) {
      setGame(classicStartPosition);
    } else if (mode === 'random' && randomPuzzle) {
      setGame(randomPuzzle);
    } else if (mode === 'daily') {
      loadDailyPuzzle();
    } else if (mode === 'random') {
      loadRandomPuzzle();
    } else {
      loadClassicGame();
    }
  }, [mode, dailyPuzzle, classicStartPosition, randomPuzzle, loadDailyPuzzle, loadClassicGame, loadRandomPuzzle]);

  // Initialize game on mount - only runs once when puzzles are loaded
  useEffect(() => {
    // Only initialize once
    if (initialized) return;
    
    if (puzzles !== null && puzzles.length > 0) {
      setInitialized(true);
      loadDailyPuzzle();
    } else if (puzzles === null) {
      // Puzzles still loading, wait a bit then fallback to classic
      const timer = setTimeout(() => {
        if (!initialized) {
          setInitialized(true);
          loadClassicGame();
        }
      }, 2000);
      return () => clearTimeout(timer);
    } else {
      // puzzles is empty array - no puzzles available
      setInitialized(true);
      loadClassicGame();
    }
  }, [puzzles, initialized, loadDailyPuzzle, loadClassicGame]);

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
      
      // Update last move highlight
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
      
      // Bot's turn - use selected bot type with 2 second delay for "thinking" effect
      if (newState.result === 'ONGOING' && newState.side_to_move === 'WHITE') {
        // Keep loading true, delay before bot moves
        await new Promise(resolve => setTimeout(resolve, 1000));
        
        const botMoveResult = await api.getBotMove(newState.sfen, selectedBot);
        
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
  }, [game, selectedBot]);

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
          const to = move.substring(2, 4);
          targets.add(to);
        }
      });
    } else if (selection.type === 'hand' && selection.pieceType) {
      const pieceChar = getPieceChar(selection.pieceType);
      game.legal_moves.forEach(move => {
        if (move.startsWith(`${pieceChar}*`)) {
          const to = move.substring(2, 4);
          targets.add(to);
        }
      });
    }
    
    return targets;
  }, [game, selection]);

  // Compute derived state
  const pieces = useMemo(() => game ? parseSfenBoard(game.sfen) : new Map(), [game?.sfen]);
  const legalTargets = useMemo(() => getLegalTargets(), [getLegalTargets]);
  const isGameOver = game !== null && game.result !== 'ONGOING';
  const resultDisplay = isGameOver ? getResultDisplay(game.result, game.side_to_move) : null;

  // Render board
  const renderBoard = () => {
    const squares = [];
    
    for (let rank = 1; rank <= 5; rank++) {
      for (let file = 1; file <= 5; file++) {
        const notation = `${file}${String.fromCharCode(96 + rank)}`;
        const piece = pieces.get(notation);
        const isSelected = selection?.type === 'board' && selection.square === notation;
        const isLegalTarget = legalTargets.has(notation);
        const isLastMoveSquare = lastMove && (lastMove.from === notation || lastMove.to === notation);
        const isMiddleRank = rank === 3 || rank === 2 || rank === 4;
        
        squares.push(
          <div
            key={notation}
            className={`square ${isSelected ? 'selected' : ''} ${isLegalTarget ? 'legal-target' : ''} ${isLastMoveSquare ? 'last-move' : ''} ${piece ? 'has-piece' : ''} ${isMiddleRank ? 'rank-middle' : ''}`}
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
      }
    }
    
    return squares;
  };

  // Render loading state
  if (!game) {
    return (
      <div className="loading">
        <div className="spinner"></div>
        <span>Loading...</span>
      </div>
    );
  }

  return (
    <>
      <h1>BitShogi</h1>
      <p className="subtitle">{bitboardInt}</p>
      
      <div className="game-container">
        {/* Left sidebar - Opponent's hand */}
        <div className="sidebar sidebar-left">
          <div className="hand">
            <p className="hand-title">Bot's Hand</p>
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
            {/* File coordinates (1-5) */}
            <div className="file-coords">
              {[1, 2, 3, 4, 5].map(f => (
                <span key={f}>{f}</span>
              ))}
            </div>
            
            <div className="board-row-wrapper">
              {/* Rank coordinates (a-e) */}
              <div className="rank-coords">
                {['a', 'b', 'c', 'd', 'e'].map(r => (
                  <span key={r} className="rank-coord">{r}</span>
                ))}
              </div>
              
              {/* Board with SVG lines */}
              <div className="board-container">
                <BoardLines />
                <div className="board">
                  {renderBoard()}
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Right sidebar - Player's hand and controls */}
        <div className="sidebar sidebar-right">
          <div className="hand">
            <p className="hand-title">Your Hand</p>
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
              <div className={`turn-indicator ${game.side_to_move === 'WHITE' ? 'thinking' : ''}`}>
                <span className={`turn-dot ${game.side_to_move === 'WHITE' ? 'pulse' : ''}`}></span>
                <span>{game.side_to_move === 'BLACK' ? 'Your turn' : 'Thinking...'}</span>
              </div>
            )}
            
            {game.is_check && !isGameOver && (
              <p className="status check">Check!</p>
            )}
            
            {isGameOver && resultDisplay && (
              <p className={`status game-over ${resultDisplay.isWin ? 'win' : ''}`}>
                {resultDisplay.text}
              </p>
            )}
            
            {error && <p className="error">{error}</p>}
            
            {loading && (
              <div className="loading">
                <div className="spinner"></div>
              </div>
            )}
            
            <div className="controls">
              {/* <button onClick={resetGame} disabled={loading}>
                Reset
              </button> */}
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
                className={`daily-btn ${mode === 'daily' ? 'active' : ''}`}
              >
                Daily
              </button>
              {/* <button 
                onClick={loadRandomPuzzle} 
                disabled={loading}
                className={`random-btn ${mode === 'random' ? 'active' : ''}`}
              >
                Random
              </button> */}
            </div>
            
            {/* Bot selector */}
            <div className="bot-selector">
              <label htmlFor="bot-select">Bot:</label>
              <select 
                id="bot-select"
                value={selectedBot}
                onChange={(e) => handleBotChange(e.target.value as BotType)}
                disabled={loading}
              >
                {BOT_OPTIONS.map(bot => (
                  <option key={bot.value} value={bot.value}>
                    {bot.label}
                  </option>
                ))}
              </select>
            </div>
          </div>

          <p className="help-text">
            Click a piece to select, then click a destination. Green dots show legal moves.
          </p>
        </div>
      </div>

      {/* Promotion dialog */}
      {promotionChoice && (
        <div className="promotion-overlay">
          <div className="promotion-dialog">
            <h3>Promote piece?</h3>
            <div className="promotion-choices">
              <div className="promotion-choice" onClick={() => handlePromotionChoice(true)}>
                <div className="piece black promoted">
                  <PieceImage type={`PROMOTED_${promotionChoice.pieceType}` as PieceType} />
                </div>
              </div>
              <div className="promotion-choice" onClick={() => handlePromotionChoice(false)}>
                <div className="piece black">
                  <PieceImage type={promotionChoice.pieceType} />
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Custom SFEN input */}
    <div className="custom-sfen">
      <p className="custom-sfen-label">SFEN board setup</p>
      <div className="custom-sfen-input">
        <input
          type="text"
          id="sfen-input"
          autoComplete="off"
          value={customSfen}
          onChange={(e) => setCustomSfen(e.target.value)}
          placeholder="e.g. rbsgk/4p/5/P4/KGSBR b - 1"
          disabled={loading}
        />
        <button onClick={loadCustomPosition} disabled={loading || !customSfen.trim()}>
          Load
        </button>
      </div>
    </div>
    
      {/* Footer */}
      <footer className="footer" style={{ textAlign: 'center'}}>
        <p>Author: Sam Ghalayini</p>
        <p><a href="https://github.com/sam-ghala/BitShogi" target="_blank" rel="noopener noreferrer">Code</a> - <Link to="/rules">Rules</Link></p>
        <p>playing a little bit every day using bitboards</p>
      </footer>
      <Analytics />
    </>
  );
}

export default App;
