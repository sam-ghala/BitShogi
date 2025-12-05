import { Link } from 'react-router-dom';
import './Rules.css';

// Movement patterns for each piece (relative to center)
// 1 = can move, 2 = can move multiple squares (sliding)
type MovePattern = (0 | 1 | 2)[][];

const PIECE_MOVES: Record<string, { pattern: MovePattern; name: string; description: string }> = {
  KING: {
    name: 'King',
    description: 'Moves one square in any direction. Capture this piece to win!',
    pattern: [
      [1, 1, 1],
      [1, 0, 1],
      [1, 1, 1],
    ],
  },
  ROOK: {
    name: 'Rook',
    description: 'Moves any number of squares orthogonally (up, down, left, right).',
    pattern: [
      [0, 2, 0],
      [2, 0, 2],
      [0, 2, 0],
    ],
  },
  BISHOP: {
    name: 'Bishop',
    description: 'Moves any number of squares diagonally.',
    pattern: [
      [2, 0, 2],
      [0, 0, 0],
      [2, 0, 2],
    ],
  },
  GOLD: {
    name: 'Gold General',
    description: 'Moves one square in 6 directions: forward, sideways, or diagonally forward.',
    pattern: [
      [1, 1, 1],
      [1, 0, 1],
      [0, 1, 0],
    ],
  },
  SILVER: {
    name: 'Silver General',
    description: 'Moves one square diagonally or one square forward.',
    pattern: [
      [1, 1, 1],
      [0, 0, 0],
      [1, 0, 1],
    ],
  },
  KNIGHT: {
    name: 'Knight',
    description: 'Jumps two squares forward and one square sideways. Can jump over pieces.',
    pattern: [
      [1, 0, 1],
      [0, 0, 0],
      [0, 0, 0],
    ],
  },
  LANCE: {
    name: 'Lance',
    description: 'Moves any number of squares forward only. Cannot move sideways or backward.',
    pattern: [
      [0, 2, 0],
      [0, 0, 0],
      [0, 0, 0],
    ],
  },
  PAWN: {
    name: 'Pawn',
    description: 'Moves one square forward only. Captures the same way it moves.',
    pattern: [
      [0, 1, 0],
      [0, 0, 0],
      [0, 0, 0],
    ],
  },
  PROMOTED_ROOK: {
    name: 'Dragon (promoted Rook)',
    description: 'Moves like a Rook, plus one square diagonally.',
    pattern: [
      [1, 2, 1],
      [2, 0, 2],
      [1, 2, 1],
    ],
  },
  PROMOTED_BISHOP: {
    name: 'Horse (promoted Bishop)',
    description: 'Moves like a Bishop, plus one square orthogonally.',
    pattern: [
      [2, 1, 2],
      [1, 0, 1],
      [2, 1, 2],
    ],
  },
};

// Mini board component showing movement pattern
function MovementDiagram({ pieceType, pattern }: { pieceType: string; pattern: MovePattern }) {
  const imgSrc = `/pieces/${pieceType.toLowerCase().replace('promoted_', '').replace('_', '-')}.svg`;
  const isPromoted = pieceType.startsWith('PROMOTED_');
  const actualSrc = isPromoted 
    ? `/pieces/${pieceType.toLowerCase().replace('promoted_', '')}-p.svg`
    : imgSrc;

  return (
    <div className="movement-diagram">
      <div className="mini-board">
        {pattern.map((row, rowIdx) =>
          row.map((cell, colIdx) => {
            const isCenter = rowIdx === 1 && colIdx === 1;
            const canMove = cell === 1;
            const canSlide = cell === 2;
            
            return (
              <div
                key={`${rowIdx}-${colIdx}`}
                className={`mini-square ${canMove ? 'can-move' : ''} ${canSlide ? 'can-slide' : ''} ${isCenter ? 'center' : ''}`}
              >
                {isCenter && (
                  <img src={actualSrc} alt={pieceType} className="diagram-piece" />
                )}
                {canSlide && <span className="slide-arrow">→</span>}
              </div>
            );
          })
        )}
      </div>
    </div>
  );
}

// Extended 5x5 diagram for knight
function KnightDiagram() {
  // Knight jumps: 2 forward, 1 to side
  const pattern = [
    [0, 1, 0, 1, 0],
    [0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0], // center row
    [0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0],
  ];
  
  return (
    <div className="movement-diagram">
      <div className="mini-board knight-board">
        {pattern.map((row, rowIdx) =>
          row.map((cell, colIdx) => {
            const isCenter = rowIdx === 2 && colIdx === 2;
            const canMove = cell === 1;
            
            return (
              <div
                key={`${rowIdx}-${colIdx}`}
                className={`mini-square ${canMove ? 'can-move' : ''} ${isCenter ? 'center' : ''}`}
              >
                {isCenter && (
                  <img src="/pieces/knight.svg" alt="Knight" className="diagram-piece" />
                )}
              </div>
            );
          })
        )}
      </div>
    </div>
  );
}

function Rules() {
  return (
    <div className="rules-page">
      <header className="rules-header">
        <Link to="/" className="back-link">← Back to Game</Link>
        <h1>BitShogi Rules</h1>
        <p className="rules-subtitle">Shogi on a 5×5 board</p>
      </header>

      <main className="rules-content">
        {/* Goal Section */}
        <section className="rules-section">
          <h2>Goal</h2>
          <div className="goal-content">
            <div className="goal-text">
              <p>
                <strong>Capture the opponent's King to win.</strong>
              </p>
              <p>
                If your King can be captured and you can't prevent it, you lose.
              </p>
            </div>
            <div className="king-display">
              <img src="/pieces/king.svg" alt="King" className="large-piece" />
              <span>The King</span>
            </div>
          </div>
        </section>

        {/* Key Difference from Chess */}
        <section className="rules-section">
          <h2>The Hand (Drops)</h2>
          <div className="hand-explanation">
            <p>
              <strong>The biggest difference from chess:</strong> When you capture a piece, 
              it goes into your <em>hand</em>. On any turn, instead of moving a piece on the board, 
              you can <strong>drop</strong> a piece from your hand onto any empty square.
            </p>
            <p>
              Dropped pieces return to their unpromoted state. This makes shogi more dynamic. Pieces 
              never leave the game, and comebacks are always possible.
            </p>
          </div>
        </section>

        {/* Piece Movements */}
        <section className="rules-section">
          <h2>How Pieces Move</h2>
          <p className="movement-legend">
            <span className="legend-item"><span className="legend-box move"></span> = one square</span>
            <span className="legend-item"><span className="legend-box slide"></span> = any number of squares</span>
          </p>
          
          <div className="pieces-grid">
            {Object.entries(PIECE_MOVES).map(([type, data]) => (
              <div key={type} className="piece-card">
                <h3>{data.name}</h3>
                {type === 'KNIGHT' ? (
                  <KnightDiagram />
                ) : (
                  <MovementDiagram pieceType={type} pattern={data.pattern} />
                )}
                <p>{data.description}</p>
              </div>
            ))}
          </div>
        </section>

        {/* Promoted Pieces Note */}
        <section className="rules-section">
          <h2>Promoted Pieces</h2>
          <p>
            When Pawn, Lance, Knight, or Silver promote, they all move like a <strong>Gold General</strong>.
          </p>
          <div className="promotion-examples">
            <div className="promo-item">
              <img src="/pieces/pawn.svg" alt="Pawn" />
              <span>→</span>
              <img src="/pieces/pawn-p.svg" alt="Promoted Pawn" />
              <span className="promo-label">moves like Gold</span>
            </div>
            <div className="promo-item">
              <img src="/pieces/lance.svg" alt="Lance" />
              <span>→</span>
              <img src="/pieces/lance-p.svg" alt="Promoted Lance" />
              <span className="promo-label">moves like Gold</span>
            </div>
            <div className="promo-item">
              <img src="/pieces/knight.svg" alt="Knight" />
              <span>→</span>
              <img src="/pieces/knight-p.svg" alt="Promoted Knight" />
              <span className="promo-label">moves like Gold</span>
            </div>
            <div className="promo-item">
              <img src="/pieces/silver.svg" alt="Silver" />
              <span>→</span>
              <img src="/pieces/silver-p.svg" alt="Promoted Silver" />
              <span className="promo-label">moves like Gold</span>
            </div>
          </div>
          <p>
            Rook and Bishop get enhanced movement when promoted (shown above as Dragon and Horse).
          </p>
        </section>

        {/* Promotion Rules */}
        <section className="rules-section">
          <h2>Promotion Rules</h2>
          <div className="promotion-zone-diagram">
            <div className="zone-board">
              <div className="zone-row promotion-zone"><span>Promotion Zone (Black)</span></div>
              <div className="zone-row"></div>
              <div className="zone-row"></div>
              <div className="zone-row"></div>
              <div className="zone-row promotion-zone white"><span>Promotion Zone (White)</span></div>
            </div>
          </div>
          <ul>
            <li>
              <strong>When entering or leaving the promotion zone</strong> (opponent's back rank), 
              you may choose to promote your piece.
            </li>
            <li>
              <strong>Pawn and Lance MUST promote</strong> when reaching the last rank 
              (they would have no legal moves otherwise).
            </li>
            <li>
              <strong>Knight MUST promote</strong> when reaching the last two ranks.
            </li>
            <li>
              Promoted pieces stay promoted until captured.
            </li>
            <li>
              Filled in circles are promotion spots. During development I'll experiment with different promotion spots. Classic mode will always be the last rank, the daily and random boards will be a mix.
            </li>
          </ul>
        </section>

        {/* Special Pawn Rules */}
        <section className="rules-section">
          <h2>Special Pawn Rules</h2>
          
          <div className="special-rule">
            <h3>Nifu (二歩) — Double Pawn</h3>
            <p>
              You <strong>cannot have two unpromoted pawns</strong> on the same file (column). 
              This applies to both board pawns and dropped pawns.
            </p>
            <div className="nifu-diagram">
              <div className="nifu-board">
                <div className="nifu-col">
                  <div className="nifu-cell"><img src="/pieces/pawn.svg" alt="Pawn" /></div>
                  <div className="nifu-cell empty"></div>
                  <div className="nifu-cell empty"></div>
                  <div className="nifu-cell blocked">✗</div>
                  <div className="nifu-cell empty"></div>
                </div>
              </div>
              <span className="nifu-label">Cannot drop another pawn in this file</span>
            </div>
          </div>

          <div className="special-rule">
            <h3>Uchifuzume (打ち歩詰め) — Pawn Drop Checkmate</h3>
            <p>
              You <strong>cannot checkmate by dropping a pawn</strong>. 
              If dropping a pawn would immediately checkmate the opponent's King with no escape, 
              that drop is illegal.
            </p>
            <p className="note">
              (Moving a pawn to give checkmate is fine—only <em>dropping</em> is restricted.)
            </p>
          </div>
        </section>

        {/* Quick Reference */}
        <section className="rules-section">
          <h2>Quick Reference</h2>
          <table className="quick-ref-table">
            <thead>
              <tr>
                <th>Piece</th>
                <th>Promotes To</th>
                <th>Can Drop?</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td>King</td>
                <td>—</td>
                <td>No (never captured)</td>
              </tr>
              <tr>
                <td>Rook</td>
                <td>Dragon</td>
                <td>Yes</td>
              </tr>
              <tr>
                <td>Bishop</td>
                <td>Horse</td>
                <td>Yes</td>
              </tr>
              <tr>
                <td>Gold</td>
                <td>—</td>
                <td>Yes</td>
              </tr>
              <tr>
                <td>Silver</td>
                <td>Gold movement</td>
                <td>Yes</td>
              </tr>
              <tr>
                <td>Knight</td>
                <td>Gold movement</td>
                <td>Yes*</td>
              </tr>
              <tr>
                <td>Lance</td>
                <td>Gold movement</td>
                <td>Yes*</td>
              </tr>
              <tr>
                <td>Pawn</td>
                <td>Gold movement</td>
                <td>Yes**</td>
              </tr>
            </tbody>
          </table>
          <p className="table-notes">
            * Cannot drop on last rank (Lance) or last two ranks (Knight)<br />
            ** Cannot drop on same file as another pawn, or to give checkmate
          </p>
        </section>
      </main>

      <footer className="rules-footer">
        <Link to="/">← Back to Game</Link>
      </footer>
    </div>
  );
}

export default Rules;
