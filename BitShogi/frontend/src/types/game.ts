export type Color = 'BLACK' | 'WHITE';

export type PieceType = 
  | 'PAWN' | 'LANCE' | 'KNIGHT' | 'SILVER' | 'GOLD' | 'BISHOP' | 'ROOK' | 'KING'
  | 'PROMOTED_PAWN' | 'PROMOTED_LANCE' | 'PROMOTED_KNIGHT' | 'PROMOTED_SILVER' 
  | 'PROMOTED_BISHOP' | 'PROMOTED_ROOK';

export interface Piece {
  type: PieceType;
  color: Color;
}

export interface HandPieces {
  BLACK: Record<string, number>;
  WHITE: Record<string, number>;
}

export interface GameState {
  sfen: string;
  side_to_move: Color;
  legal_moves: string[];
  is_check: boolean;
  result: string;
  hand: HandPieces;
}

export interface MoveResponse {
  success: boolean;
  sfen?: string;
  side_to_move?: Color;
  legal_moves?: string[];
  is_check?: boolean;
  result?: string;
  hand?: HandPieces;
  error?: string;
}

export interface BotMoveResponse {
  success: boolean;
  move?: string;
  error?: string;
}

// Selection can be either a board square or a hand piece
export interface Selection {
  type: 'board' | 'hand';
  square?: string;      // For board selection: "1a", "3c", etc.
  pieceType?: PieceType; // For hand selection
}
