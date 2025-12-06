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
  return fetchJson(`${API_BASE}/game/new`);
}

export async function makeMove(sfen: string, move: string): Promise<MoveResponse> {
  return fetchJson(`${API_BASE}/game/move`, {
    method: 'POST',
    body: JSON.stringify({ sfen, move }),
  });
}

export async function getBotMove(sfen: string, botType: string = 'greedy'): Promise<BotMoveResponse> {
  return fetchJson(`${API_BASE}/game/bot-move`, {
    method: 'POST',
    body: JSON.stringify({ sfen, bot_type: botType }),
  });
}

export interface LoadPositionResponse extends GameState {
  success: boolean;
  bitboard?: number;
}

export async function loadPosition(sfen: string): Promise<LoadPositionResponse> {
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
  if (!response.ok) throw new Error('Failed to load puzzles');
  return response.json();
}

export interface ClaudeMoveResult {
  success: boolean;
  move?: string;
  reasoning?: string;
  error?: string;
}

export async function getClaudeMove(sfen: string): Promise<ClaudeMoveResult> {
  try {
    return await fetchJson(`${API_BASE}/game/claude-move`, {
      method: 'POST',
      body: JSON.stringify({ sfen }),
    });
  } catch (e: any) {
    return { success: false, error: e.message || 'Request failed' };
  }
}

// Re-export types for convenience
export type { GameState, MoveResponse, BotMoveResponse };