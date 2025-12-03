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
