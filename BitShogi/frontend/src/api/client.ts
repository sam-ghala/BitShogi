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


// Claude bot (non-streaming)
export interface ClaudeMoveResult {
  success: boolean;
  move?: string;
  reasoning?: string;
  error?: string;
}

export async function getClaudeMove(sfen: string): Promise<ClaudeMoveResult> {
  try {
    const response = await fetch(`${API_BASE}/game/claude-move`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ sfen }),
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({ error: 'Request failed' }));
      return { success: false, error: error.error || 'Claude request failed' };
    }

    return response.json();
  } catch (e: any) {
    return { success: false, error: e.message || 'Request failed' };
  }
}