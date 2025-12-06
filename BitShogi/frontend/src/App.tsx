import { useState, useCallback, useEffect, useMemo, useRef } from 'react';
import { Link } from 'react-router-dom';
import { Analytics } from "@vercel/analytics/react"
import './index.css';
import * as api from './api/client';
import type { MoveResponse } from './api/client';

// Types
type PieceType = 'PAWN' | 'LANCE' | 'KNIGHT' | 'SILVER' | 'GOLD' | 'BISHOP' | 'ROOK' | 'KING' |
                 'PROMOTED_PAWN' | 'PROMOTED_LANCE' | 'PROMOTED_KNIGHT' | 'PROMOTED_SILVER' |
                 'PROMOTED_BISHOP' | 'PROMOTED_ROOK';
type Color = 'BLACK' | 'WHITE';
type BotType = 'random' | 'greedy' | 'easy_minimax' | 'minimax' | 'claude';

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

// Piece assets
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

const PIECE_SYMBOLS: Record<string, string> = {
  PAWN: '歩', LANCE: '香', KNIGHT: '桂', SILVER: '銀',
  GOLD: '金', BISHOP: '角', ROOK: '飛', KING: '王',
  PROMOTED_PAWN: 'と', PROMOTED_LANCE: '杏', PROMOTED_KNIGHT: '圭',
  PROMOTED_SILVER: '全', PROMOTED_BISHOP: '馬', PROMOTED_ROOK: '龍',
};

const BOT_FRAMES: Record<BotType, string[]> = {
  random: ['/bots/dice-5.svg', '/bots/dice-3.svg', '/bots/dice-2.svg', '/bots/dice-6.svg', '/bots/dice-4.svg', '/bots/dice-1.svg'],
  greedy: ['/bots/coin-one.svg', '/bots/coin-two.svg', '/bots/coin-three.svg'],
  easy_minimax: ['/bots/easy_minimax-one.svg', '/bots/easy_minimax-two.svg', '/bots/easy_minimax-three.svg'],
  minimax: ['/bots/minimax-one.svg', '/bots/minimax-two.svg', '/bots/minimax-three.svg'],
  claude: ['/bots/claude-arms-down.svg', '/bots/claude-arms-up.svg', '/bots/claude-head-off.svg', '/bots/claude-arms-up.svg'],
};

const BOT_OPTIONS: { value: BotType; label: string }[] = [
  { value: 'random', label: 'Random' },
  { value: 'greedy', label: 'Greedy' },
  { value: 'easy_minimax', label: 'Easy minimax' },
  { value: 'claude', label: 'Claude' },
  { value: 'minimax', label: 'Minimax' },
];

function apiToGameState(response: MoveResponse): GameState {
  return {
    sfen: response.sfen!,
    side_to_move: response.side_to_move!,
    legal_moves: response.legal_moves!,
    is_check: response.is_check!,
    result: response.result!,
    hand: response.hand!,
  };
}

function parseMoveSquares(move: string): { from?: string; to: string } {
  const isDrop = move.includes('*');
  return {
    from: isDrop ? undefined : move.substring(0, 2),
    to: move.substring(isDrop ? 2 : 2, isDrop ? 4 : 4),
  };
}

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

function parseSfenBoard(sfen: string): Map<string, Piece> {
  const pieces = new Map<string, Piece>();
  const boardPart = sfen.split(' ')[0];
  const ranks = boardPart.split('/');
  
  const pieceMap: Record<string, { type: PieceType; color: Color }> = {
    'P': { type: 'PAWN', color: 'BLACK' }, 'L': { type: 'LANCE', color: 'BLACK' },
    'N': { type: 'KNIGHT', color: 'BLACK' }, 'S': { type: 'SILVER', color: 'BLACK' },
    'G': { type: 'GOLD', color: 'BLACK' }, 'B': { type: 'BISHOP', color: 'BLACK' },
    'R': { type: 'ROOK', color: 'BLACK' }, 'K': { type: 'KING', color: 'BLACK' },
    'p': { type: 'PAWN', color: 'WHITE' }, 'l': { type: 'LANCE', color: 'WHITE' },
    'n': { type: 'KNIGHT', color: 'WHITE' }, 's': { type: 'SILVER', color: 'WHITE' },
    'g': { type: 'GOLD', color: 'WHITE' }, 'b': { type: 'BISHOP', color: 'WHITE' },
    'r': { type: 'ROOK', color: 'WHITE' }, 'k': { type: 'KING', color: 'WHITE' },
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
    PAWN: 'P', LANCE: 'L', KNIGHT: 'N', SILVER: 'S', GOLD: 'G', BISHOP: 'B', ROOK: 'R',
  };
  return map[type] || '?';
}

function isPromoted(type: PieceType): boolean {
  return type.startsWith('PROMOTED_');
}

function getResultDisplay(result: string, sideToMove: string): { text: string; isWin: boolean } {
  const r = result.toUpperCase().trim();
  
  if (r.includes('BLACK_WIN') || r.includes('BLACKWIN')) return { text: 'You Win!', isWin: true };
  if (r.includes('WHITE_WIN') || r.includes('WHITEWIN')) return { text: 'Bot Wins', isWin: false };
  
  if (r.includes('CHECKMATE') || r.includes('MATE')) {
    if (r.includes('WHITE') || r.includes('W_')) return { text: 'You Win!', isWin: true };
    if (r.includes('BLACK') || r.includes('B_')) return { text: 'Bot Wins', isWin: false };
    return sideToMove === 'WHITE' ? { text: 'You Win!', isWin: true } : { text: 'Bot Wins', isWin: false };
  }
  
  if (r.includes('STALEMATE')) return { text: 'Draw (Stalemate)', isWin: false };
  if (r.includes('DRAW')) return { text: 'Draw', isWin: false };
  
  return { text: `Game Over: ${result}`, isWin: false };
}

function BoardLines() {
  const size = 64;
  const totalSize = 5 * size;
  const lines: JSX.Element[] = [];
  
  for (let row = 0; row < 5; row++) {
    for (let col = 0; col < 5; col++) {
      const cx = col * size + size / 2;
      const cy = row * size + size / 2;
      
      if (col < 4) lines.push(<line key={`h-${row}-${col}`} x1={cx} y1={cy} x2={cx + size} y2={cy} />);
      if (row < 4) lines.push(<line key={`v-${row}-${col}`} x1={cx} y1={cy} x2={cx} y2={cy + size} />);
      if (col < 4 && row < 4) lines.push(<line key={`dr-${row}-${col}`} x1={cx} y1={cy} x2={cx + size} y2={cy + size} />);
      if (col > 0 && row < 4) lines.push(<line key={`dl-${row}-${col}`} x1={cx} y1={cy} x2={cx - size} y2={cy + size} />);
    }
  }
  
  return (
    <svg className="board-lines" viewBox={`0 0 ${totalSize} ${totalSize}`} preserveAspectRatio="none">
      {lines}
    </svg>
  );
}

function App() {
  const [game, setGame] = useState<GameState | null>(null);
  const [selection, setSelection] = useState<Selection | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [customSfen, setCustomSfen] = useState('');
  const [lastMove, setLastMove] = useState<{ from?: string; to?: string } | null>(null);
  const [promotionChoice, setPromotionChoice] = useState<{ from: string; to: string; pieceType: PieceType } | null>(null);
  
  const [bitboardInt, setBitboardInt] = useState(32539167);
  const [dailyPuzzle, setDailyPuzzle] = useState<GameState | null>(null);
  const [randomPuzzle, setRandomPuzzle] = useState<GameState | null>(null);
  const [classicStartPosition, setClassicStartPosition] = useState<GameState | null>(null);
  const [mode, setMode] = useState<'daily' | 'classic' | 'random'>('daily');
  const [puzzles, setPuzzles] = useState<api.PuzzleData[] | null>(null);
  const [initialized, setInitialized] = useState(false);
  
  const [selectedBot, setSelectedBot] = useState<BotType>('minimax');
  const [animatingBot, setAnimatingBot] = useState<BotType | null>(null);
  const [animationFrame, setAnimationFrame] = useState(0);
  
  const [claudeReasoning, setClaudeReasoning] = useState('');
  const [claudeThinking, setClaudeThinking] = useState(false);
  const [claudeThinkingFrame, setClaudeThinkingFrame] = useState(0);
  const reasoningRef = useRef<HTMLPreElement>(null);

  useEffect(() => {
    if (reasoningRef.current) {
      reasoningRef.current.scrollTop = reasoningRef.current.scrollHeight;
    }
  }, [claudeReasoning]);

  // Animate Claude bot while thinking
  useEffect(() => {
    if (!claudeThinking) {
      setClaudeThinkingFrame(0);
      return;
    }
    
    const frames = BOT_FRAMES.claude;
    const interval = setInterval(() => {
      setClaudeThinkingFrame(prev => (prev + 1) % frames.length);
    }, 300);
    
    return () => clearInterval(interval);
  }, [claudeThinking]);

  const getTodayPuzzleIndex = useCallback(() => {
    const now = new Date();
    const start = new Date(now.getFullYear(), 0, 0);
    const diff = now.getTime() - start.getTime();
    return Math.floor(diff / (1000 * 60 * 60 * 24));
  }, []);

  useEffect(() => {
    api.loadPuzzles()
      .then(data => setPuzzles(data))
      .catch(err => console.warn('Failed to load puzzles.json:', err));
  }, []);

  const makeBotMove = useCallback(async (currentSfen: string, delayMs: number = 1000) => {
    if (selectedBot === 'claude') {
      setClaudeThinking(true);
      setClaudeReasoning('');
      
      const claudeResult = await api.getClaudeMove(currentSfen);
      setClaudeThinking(false);
      
      if (claudeResult.success && claudeResult.move) {
        const displayText = (claudeResult.reasoning || '').replace(/MOVE:\s*[A-Za-z0-9\+\*]+\s*$/i, '').trim();
        setClaudeReasoning(displayText);
        
        const { from, to } = parseMoveSquares(claudeResult.move);
        const afterBotMove = await api.makeMove(currentSfen, claudeResult.move);
        
        if (afterBotMove.success) {
          setLastMove({ from, to });
          setGame(apiToGameState(afterBotMove));
        }
      } else {
        setError(claudeResult.error || 'Claude failed to respond');
      }
    } else {
      await new Promise(resolve => setTimeout(resolve, delayMs));
      const botMoveResult = await api.getBotMove(currentSfen, selectedBot);
      
      if (botMoveResult.success && botMoveResult.move) {
        const { from, to } = parseMoveSquares(botMoveResult.move);
        const afterBotMove = await api.makeMove(currentSfen, botMoveResult.move);
        
        if (afterBotMove.success) {
          setLastMove({ from, to });
          setGame(apiToGameState(afterBotMove));
        }
      }
    }
  }, [selectedBot]);

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
      
      const newGame = await api.newGame();
      setBitboardInt(32539167);
      setGame(newGame);
      setClassicStartPosition(newGame);
      setMode('classic');
    } catch (e: any) {
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
      
      const newGame = await api.newGame();
      setBitboardInt(32539167);
      setGame(newGame);
      setClassicStartPosition(newGame);
      setMode('classic');
    } catch (e: any) {
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
      let sfen = customSfen.trim();
      const parts = sfen.split(' ');
      if (parts.length >= 2) {
        parts[1] = parts[1] === 'w' ? 'b' : 'w';
        sfen = parts.join(' ');
      }
      
      const gameState = await api.loadPosition(sfen);
      
      if (gameState.success) {
        setBitboardInt(gameState.bitboard ?? 0);
        setGame(gameState);
        setRandomPuzzle(gameState);
        
        if (gameState.side_to_move === 'WHITE' && gameState.result === 'ONGOING') {
          await makeBotMove(gameState.sfen, 500);
        }
      } else {
        setError('Invalid SFEN format');
      }
    } catch (e: any) {
      setError(e.message || 'Failed to load position');
    }
    setLoading(false);
  }, [customSfen, makeBotMove]);

  const handleBotChange = useCallback((newBot: BotType) => {
    const frames = BOT_FRAMES[newBot];
    if (frames && frames.length > 1) {
      setAnimatingBot(newBot);
      setAnimationFrame(0);
      
      let frame = 0;
      const totalFrames = frames.length * 3;
      
      const interval = setInterval(() => {
        frame++;
        if (frame >= totalFrames) {
          clearInterval(interval);
          setAnimatingBot(null);
          setAnimationFrame(0);
        } else {
          setAnimationFrame(frame % frames.length);
        }
      }, 260);
    }
    
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
      const newState = apiToGameState(afterPlayerMove);
      setGame(newState);
      
      if (newState.result === 'ONGOING' && newState.side_to_move === 'WHITE') {
        await makeBotMove(newState.sfen, 1000);
      }
      
      setLoading(false);
    } catch (e: any) {
      setError(e.message || 'Move failed');
      setLoading(false);
    }
  }, [game, makeBotMove]);

  const handleSquareClick = useCallback((notation: string) => {
    if (!game || game.side_to_move !== 'BLACK' || loading || game.result !== 'ONGOING') return;
    
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
            setPromotionChoice({ from: selection.square, to: notation, pieceType: piece.type });
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
    if (!game || game.side_to_move !== color || loading || game.result !== 'ONGOING' || color !== 'BLACK') return;
    
    if (selection?.type === 'hand' && selection.pieceType === pieceType) {
      setSelection(null);
    } else {
      setSelection({ type: 'hand', pieceType });
    }
  }, [game, selection, loading]);

  const handlePromotionChoice = useCallback((promote: boolean) => {
    if (!promotionChoice) return;
    executeMove(`${promotionChoice.from}${promotionChoice.to}${promote ? '+' : ''}`, promotionChoice.from, promotionChoice.to);
    setPromotionChoice(null);
  }, [promotionChoice, executeMove]);

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

  const pieces = useMemo(() => game ? parseSfenBoard(game.sfen) : new Map(), [game?.sfen]);
  const legalTargets = useMemo(() => getLegalTargets(), [getLegalTargets]);
  const isGameOver = game !== null && game.result !== 'ONGOING';
  const resultDisplay = isGameOver ? getResultDisplay(game.result, game.side_to_move) : null;

  const getBotIcon = (botType: BotType): string => {
    const frames = BOT_FRAMES[botType];
    if (animatingBot === botType && frames) return frames[animationFrame];
    return frames ? frames[0] : '';
  };

  const renderBoard = () => {
    const squares = [];
    
    for (let rank = 1; rank <= 5; rank++) {
      for (let file = 1; file <= 5; file++) {
        const notation = `${file}${String.fromCharCode(96 + rank)}`;
        const piece = pieces.get(notation);
        const isSelected = selection?.type === 'board' && selection.square === notation;
        const isLegalTarget = legalTargets.has(notation);
        const isLastMoveSquare = lastMove && (lastMove.from === notation || lastMove.to === notation);
        const isMiddleRank = rank === 2 || rank === 3 || rank === 4;
        
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

        <div className="board-wrapper">
          <div className="board-with-coords">
            <div className="file-coords">
              {[1, 2, 3, 4, 5].map(f => <span key={f}>{f}</span>)}
            </div>
            
            <div className="board-row-wrapper">
              <div className="rank-coords">
                {['a', 'b', 'c', 'd', 'e'].map(r => <span key={r} className="rank-coord">{r}</span>)}
              </div>
              
              <div className="board-container">
                <BoardLines />
                <div className="board">{renderBoard()}</div>
              </div>
            </div>
          </div>
        </div>

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

          <div className="game-info">
            {!isGameOver && (
              <div className={`turn-indicator ${game.side_to_move === 'WHITE' ? 'thinking' : ''}`}>
                <span className={`turn-dot ${game.side_to_move === 'WHITE' ? 'pulse' : ''}`}></span>
                <span>
                  {game.side_to_move === 'BLACK' 
                    ? 'Your turn' 
                    : (claudeThinking ? 'Claude is thinking...' : 'Thinking...')}
                </span>
              </div>
            )}
            
            {game.is_check && !isGameOver && <p className="status check">Check!</p>}
            
            {isGameOver && resultDisplay && (
              <p className={`status game-over ${resultDisplay.isWin ? 'win' : ''}`}>{resultDisplay.text}</p>
            )}
            
            {error && <p className="error">{error}</p>}
            
            {loading && !claudeThinking && (
              <div className="loading"><div className="spinner"></div></div>
            )}
            
            <div className="controls">
              <button onClick={loadClassicGame} disabled={loading} className={mode === 'classic' ? 'active' : ''}>
                Classic
              </button>
              <button onClick={loadDailyPuzzle} disabled={loading} className={`daily-btn ${mode === 'daily' ? 'active' : ''}`}>
                Daily
              </button>
            </div>
          </div>

          <p className="help-text">Click a piece to select, then click a destination. Green dots show legal moves.</p>
        </div>
      </div>

      {selectedBot === 'claude' && (claudeReasoning || claudeThinking) && (
        <div className="claude-reasoning">
          <p className="reasoning-title">
            {claudeThinking ? 'Claude is thinking...' : 'Claude\'s reasoning:'}
          </p>
          
          {claudeThinking ? (
            <div className="claude-thinking-animation">
              <img 
                src={BOT_FRAMES.claude[claudeThinkingFrame]} 
                alt="Claude thinking" 
                className="claude-thinking-icon" 
              />
            </div>
          ) : (
            <pre ref={reasoningRef} className="reasoning-text">{claudeReasoning}</pre>
          )}
        </div>
      )}

      <div className="bot-selector-tiles">
        <p className="bot-selector-label">Choose Opponent</p>
        <div className="bot-tiles">
          {BOT_OPTIONS.map(bot => (
            <button
              key={bot.value}
              className={`bot-tile bot-tile-${bot.value} ${selectedBot === bot.value ? 'selected' : ''}`}
              onClick={() => handleBotChange(bot.value)}
              disabled={loading}
            >
              <img src={getBotIcon(bot.value)} alt={bot.label} className="bot-tile-icon" />
              <span className="bot-tile-label">{bot.label}</span>
            </button>
          ))}
        </div>
      </div>

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

      <div className="custom-sfen">
        <p className="custom-sfen-label">SFEN board setup</p>
        <div className="custom-sfen-input">
          <input
            type="text"
            id="sfen-input"
            autoComplete="off"
            value={customSfen}
            onChange={(e) => setCustomSfen(e.target.value)}
            placeholder="e.g. rbsgk/4p/5/P4/KGSBR w - 1"
            disabled={loading}
          />
          <button onClick={loadCustomPosition} disabled={loading || !customSfen.trim()}>Load</button>
        </div>
      </div>
    
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