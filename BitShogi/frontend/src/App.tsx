import { useState, useCallback, useEffect, useMemo, useRef } from 'react';
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

// Piece component
function PieceImage({ type, className }: { type: string; className?: string }) {
  const imgSrc = PIECE_IMAGES[type];
  const fallback = PIECE_SYMBOLS[type] || '?';
  
  return (
    <img 
      src={imgSrc} 
      alt={type}
      className={`piece-img ${className || ''}`}
      onError={(e) => {
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

function getPieceChar(type: PieceType): string {
  const map: Record<string, string> = {
    PAWN: 'P', LANCE: 'L', KNIGHT: 'N', SILVER: 'S',
    GOLD: 'G', BISHOP: 'B', ROOK: 'R',
  };
  return map[type] || '?';
}

function isPromoted(type: PieceType): boolean {
  return type.startsWith('PROMOTED_');
}

function getResultDisplay(result: string, sideToMove: string): { text: string; isWin: boolean } {
  const resultUpper = result.toUpperCase().trim();
  
  if (resultUpper.includes('BLACK_WIN') || resultUpper.includes('BLACKWIN')) {
    return { text: 'You Win!', isWin: true };
  }
  
  if (resultUpper.includes('WHITE_WIN') || resultUpper.includes('WHITEWIN')) {
    return { text: 'Bot Wins', isWin: false };
  }
  
  if (resultUpper.includes('CHECKMATE') || resultUpper.includes('MATE')) {
    if (resultUpper.includes('WHITE') || resultUpper.includes('W_')) {
      return { text: 'You Win!', isWin: true };
    }
    if (resultUpper.includes('BLACK') || resultUpper.includes('B_')) {
      return { text: 'Bot Wins', isWin: false };
    }
    if (sideToMove === 'WHITE') {
      return { text: 'You Win!', isWin: true };
    } else {
      return { text: 'Bot Wins', isWin: false };
    }
  }
  
  if (resultUpper.includes('STALEMATE')) {
    return { text: 'Draw (Stalemate)', isWin: false };
  }
  
  if (resultUpper.includes('DRAW')) {
    return { text: 'Draw', isWin: false };
  }
  
  return { text: `Game Over: ${result}`, isWin: false };
}

// Types
type PieceType = 'PAWN' | 'LANCE' | 'KNIGHT' | 'SILVER' | 'GOLD' | 'BISHOP' | 'ROOK' | 'KING' |
                 'PROMOTED_PAWN' | 'PROMOTED_LANCE' | 'PROMOTED_KNIGHT' | 'PROMOTED_SILVER' |
                 'PROMOTED_BISHOP' | 'PROMOTED_ROOK';
type Color = 'BLACK' | 'WHITE';
type BotType = 'random' | 'greedy' | 'easy_minimax' | 'claude' | 'minimax';

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

function BoardLines() {
  const size = 64;
  const totalSize = 5 * size;
  const lines: JSX.Element[] = [];
  
  for (let row = 0; row < 5; row++) {
    for (let col = 0; col < 5; col++) {
      const cx = col * size + size / 2;
      const cy = row * size + size / 2;
      
      if (col < 4) {
        lines.push(<line key={`h-${row}-${col}`} x1={cx} y1={cy} x2={cx + size} y2={cy} />);
      }
      if (row < 4) {
        lines.push(<line key={`v-${row}-${col}`} x1={cx} y1={cy} x2={cx} y2={cy + size} />);
      }
      if (col < 4 && row < 4) {
        lines.push(<line key={`dr-${row}-${col}`} x1={cx} y1={cy} x2={cx + size} y2={cy + size} />);
      }
      if (col > 0 && row < 4) {
        lines.push(<line key={`dl-${row}-${col}`} x1={cx} y1={cy} x2={cx - size} y2={cy + size} />);
      }
    }
  }
  
  return (
    <svg className="board-lines" viewBox={`0 0 ${totalSize} ${totalSize}`} preserveAspectRatio="none">
      {lines}
    </svg>
  );
}

// Available bots with display names
const BOT_OPTIONS: { value: BotType; label: string }[] = [
  { value: 'random', label: 'Random' },
  { value: 'greedy', label: 'Greedy' },
  { value: 'easy_minimax', label: 'Easy Minimax' },
  { value: 'claude', label: 'Claude' },
  { value: 'minimax', label: 'Minimax' },
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
  const [selectedBot, setSelectedBot] = useState<BotType>('minimax');
  
  // Claude reasoning state
  const [claudeReasoning, setClaudeReasoning] = useState<string>('');
  const [claudeThinking, setClaudeThinking] = useState(false);
  const reasoningRef = useRef<HTMLPreElement>(null);

  // Auto-scroll reasoning box
  useEffect(() => {
    if (reasoningRef.current) {
      reasoningRef.current.scrollTop = reasoningRef.current.scrollHeight;
    }
  }, [claudeReasoning]);

  const getTodayPuzzleIndex = useCallback(() => {
    const now = new Date();
    const start = new Date(now.getFullYear(), 0, 0);
    const diff = now.getTime() - start.getTime();
    const oneDay = 1000 * 60 * 60 * 24;
    const dayOfYear = Math.floor(diff / oneDay);
    return dayOfYear;
  }, []);

  useEffect(() => {
    api.loadPuzzles()
      .then(data => setPuzzles(data))
      .catch(err => console.warn('Failed to load puzzles.json:', err));
  }, []);

  const loadDailyPuzzle = useCallback(async () => {
    setLoading(true);
    setError(null);
    setSelection(null);
    setLastMove(null);
    setMode('daily');
    setClaudeReasoning('');
    
    try {
      if (puzzles && puzzles.length > 0) {
        const dayIndex = getTodayPuzzleIndex();
        const puzzleIndex = (dayIndex - 1) % puzzles.length;
        const todayPuzzle = puzzles[puzzleIndex];
        
        setBitboardInt(todayPuzzle.bitboard);
        
        const gameState = await api.loadPosition(todayPuzzle.sfen);
        if (gameState.success) {
          setDailyPuzzle(gameState);
          setGame(gameState);
          setLoading(false);
          return;
        }
      }
      
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

  const loadClassicGame = useCallback(async () => {
    setLoading(true);
    setError(null);
    setSelection(null);
    setLastMove(null);
    setMode('classic');
    setBitboardInt(32539167);
    setClaudeReasoning('');
    try {
      const newGame = await api.newGame();
      setClassicStartPosition(newGame);
      setGame(newGame);
    } catch (e: any) {
      setError(e.message || 'Failed to start game');
    }
    setLoading(false);
  }, []);

  const loadRandomPuzzle = useCallback(async () => {
    setLoading(true);
    setError(null);
    setSelection(null);
    setLastMove(null);
    setMode('random');
    setClaudeReasoning('');
    
    try {
      if (puzzles && puzzles.length > 0) {
        const randomIndex = Math.floor(Math.random() * puzzles.length);
        const puzzle = puzzles[randomIndex];
        
        setBitboardInt(puzzle.bitboard);
        
        const gameState = await api.loadPosition(puzzle.sfen);
        if (gameState.success) {
          setRandomPuzzle(gameState);
          setGame(gameState);
          setLoading(false);
          return;
        }
      }
      
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

  (window as any).loadRandomPuzzle = loadRandomPuzzle;

  const loadCustomPosition = useCallback(async () => {
    if (!customSfen.trim()) return;
    
    setLoading(true);
    setError(null);
    setSelection(null);
    setLastMove(null);
    setMode('random');
    setClaudeReasoning('');
    
    try {
      const gameState = await api.loadPosition(customSfen.trim());
      if (gameState.success) {
        setBitboardInt(0);
        setGame(gameState);
      } else {
        setError('Invalid SFEN format');
      }
    } catch (e: any) {
      setError(e.message || 'Failed to load position');
    }
    setLoading(false);
  }, [customSfen]);

  const resetGame = useCallback(() => {
    setSelection(null);
    setLastMove(null);
    setError(null);
    setClaudeReasoning('');
    
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

  const handleBotChange = useCallback((newBot: BotType) => {
    setSelectedBot(newBot);
    setSelection(null);
    setLastMove(null);
    setError(null);
    setClaudeReasoning('');
    
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

  useEffect(() => {
    if (initialized) return;
    
    if (puzzles !== null && puzzles.length > 0) {
      setInitialized(true);
      loadDailyPuzzle();
    } else if (puzzles === null) {
      const timer = setTimeout(() => {
        if (!initialized) {
          setInitialized(true);
          loadClassicGame();
        }
      }, 2000);
      return () => clearTimeout(timer);
    } else {
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
        
        if (selectedBot === 'claude') {
          // Use Claude bot
          setClaudeThinking(true);
          setClaudeReasoning('');
          
          const claudeResult = await api.getClaudeMove(newState.sfen);
          
          setClaudeThinking(false);
          
          if (claudeResult.success && claudeResult.move) {
            // Show reasoning (remove the MOVE: line for display)
            const displayText = (claudeResult.reasoning || '')
              .replace(/MOVE:\s*[A-Za-z0-9\+\*]+\s*$/i, '')
              .trim();
            setClaudeReasoning(displayText);
            
            const botFrom = claudeResult.move.includes('*') 
              ? undefined 
              : claudeResult.move.substring(0, 2);
            const botTo = claudeResult.move.includes('*')
              ? claudeResult.move.substring(2, 4)
              : claudeResult.move.substring(2, 4);
            
            const afterBotMove = await api.makeMove(newState.sfen, claudeResult.move);
            
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
          } else {
            setError(claudeResult.error || 'Claude failed to respond');
            setClaudeReasoning('');
          }
          setLoading(false);
        } else {
          // Use regular bot
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
          setLoading(false);
        }
      } else {
        setLoading(false);
      }
    } catch (e: any) {
      setError(e.message || 'Move failed');
      setLoading(false);
    }
  }, [game, selectedBot]);

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

  const handlePromotionChoice = useCallback((promote: boolean) => {
    if (!promotionChoice) return;
    
    const moveStr = `${promotionChoice.from}${promotionChoice.to}${promote ? '+' : ''}`;
    executeMove(moveStr, promotionChoice.from, promotionChoice.to);
    setPromotionChoice(null);
  }, [promotionChoice, executeMove]);

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

  const pieces = useMemo(() => game ? parseSfenBoard(game.sfen) : new Map(), [game?.sfen]);
  const legalTargets = useMemo(() => getLegalTargets(), [getLegalTargets]);
  const isGameOver = game !== null && game.result !== 'ONGOING';
  const resultDisplay = isGameOver ? getResultDisplay(game.result, game.side_to_move) : null;

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
            <div className="file-coords">
              {[1, 2, 3, 4, 5].map(f => (
                <span key={f}>{f}</span>
              ))}
            </div>
            
            <div className="board-row-wrapper">
              <div className="rank-coords">
                {['a', 'b', 'c', 'd', 'e'].map(r => (
                  <span key={r} className="rank-coord">{r}</span>
                ))}
              </div>
              
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
                <span>
                  {game.side_to_move === 'BLACK' 
                    ? 'Your turn' 
                    : (claudeThinking ? 'Claude thinking...' : 'Thinking...')}
                </span>
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
            
            {loading && !claudeThinking && (
              <div className="loading">
                <div className="spinner"></div>
              </div>
            )}
            
            <div className="controls">
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

      {/* Claude reasoning display */}
      {selectedBot === 'claude' && (claudeReasoning || claudeThinking) && (
        <div className="claude-reasoning">
          <p className="reasoning-title">
            {claudeThinking ? 'Claude is thinking...' : 'Claude\'s reasoning:'}
          </p>
          
          {claudeThinking ? (
            <div className="printer-animation">
              <div className="printer-container">
                {/* 1. Top Face (Lid) */}
                <div className="printer-top"></div>
                
                {/* 2. Right Face (Side Panel) */}
                <div className="printer-side"></div>
                
                {/* 3. Front Face (Contains mechanism) */}
                <div className="printer-front">
                  <div className="slit-cover"></div>
                  <div className="slit-hole"></div>
                  <div className="paper"></div>
                  <div className="printer-light"></div>
                </div>
              </div>
            </div>
          ) : (
            <pre ref={reasoningRef} className="reasoning-text">
              {claudeReasoning}
            </pre>
          )}
        </div>
      )}

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
        {/* - <Link to="/bots">Bots</Link></p> */}
        <p>playing a little bit every day using bitboards</p>
      </footer>
      <Analytics />
    </>
  );
}

export default App;