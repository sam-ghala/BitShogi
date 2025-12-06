import { Link } from 'react-router-dom';
import './Bots.css';

import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter';
import { oneDark } from 'react-syntax-highlighter/dist/esm/styles/prism';
import { useState, useEffect, useRef } from 'react';

import RandomIcon from '../public/bots/dice-5.svg';
import GreedyIcon from '../public/bots/coin-one.svg';
import MinimaxIcon from '../public/bots/minimax-two.svg';
import ClaudeIcon from '../public/bots/claude-arms-down.svg';
interface TreeNode {
  id: string; // Add unique id for tracking expanded state
  label: string;
  links: { label: string; url: string }[]; // Changed to labeled links
  left?: TreeNode;
  right?: TreeNode;
}

interface ResourceTreeProps {
  tree: TreeNode;
}
function ResourceTreeNode({ node }: { node: TreeNode }) {
  const [isExpanded, setIsExpanded] = useState(false);
  const nodeRef = useRef<HTMLDivElement>(null);

  // Close when clicking outside
  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (nodeRef.current && !nodeRef.current.contains(event.target as Node)) {
        setIsExpanded(false);
      }
    }
    
    if (isExpanded) {
      document.addEventListener('mousedown', handleClickOutside);
    }
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [isExpanded]);

  return (
    <div className="tree-node-wrapper" ref={nodeRef}>
      <button 
        className={`tree-node ${isExpanded ? 'expanded' : ''}`} 
        onClick={() => setIsExpanded(!isExpanded)}
      >
        <span className="tree-node-label">{node.label}</span>
        <span className="tree-node-link-count">
          {node.links.length} link{node.links.length > 1 ? 's' : ''}
        </span>
      </button>
      
      {isExpanded && (
        <div className="tree-node-links">
          {node.links.map((item, index) => (
            <a
              key={index}
              href={item.url}
              target="_blank"
              rel="noopener noreferrer"
              className="tree-link"
            >
              {item.label}
            </a>
          ))}
        </div>
      )}
    </div>
  );
}

function ResourceTree({ tree }: ResourceTreeProps) {
  const hasChildren = tree.left || tree.right;

  return (
    <div className="resource-tree">
      <h4>Resource Tree</h4>
      <div className="tree-container">
        {/* Root node */}
        <div className="tree-level tree-root">
          <ResourceTreeNode node={tree} />
        </div>

        {/* Children level */}
        {hasChildren && (
          <>
            <div className="tree-branches">
              {tree.left && <div className="tree-branch left" />}
              {tree.right && <div className="tree-branch right" />}
            </div>
            <div className="tree-level tree-children">
              <div className="tree-child left">
                {tree.left && <ResourceTreeNode node={tree.left} />}
              </div>
              <div className="tree-child right">
                {tree.right && <ResourceTreeNode node={tree.right} />}
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

// ==================== BOT RESOURCE TREES ====================

const randomBotTree: TreeNode = {
  id: "julia-random",
  label: "Julia Random Docs",
  links: [
    { label: "Random stdlib", url: "https://docs.julialang.org/en/v1/stdlib/Random/" },
    { label: "RNGs.jl source", url: "https://github.com/JuliaLang/julia/blob/master/stdlib/Random/src/RNGs.jl" }
  ],
  left: {
    id: "xoshiro",
    label: "Xoshiro++",
    links: [
      { label: "PRNG algorithms", url: "https://prng.di.unimi.it/" }
    ]
  },
  right: {
    id: "linux-random",
    label: "Linux Random Docs",
    links: [
      { label: "getrandom(2)", url: "https://man7.org/linux/man-pages/man2/getrandom.2.html" },
      { label: "urandom(4)", url: "https://www.man7.org/linux/man-pages/man4/urandom.4.html" },
      { label: "random(7)", url: "https://www.man7.org/linux//man-pages/man7/random.7.html" }
    ]
  }
};

const greedyBotTree: TreeNode = {
  id: "greedy-algo",
  label: "Greedy Algorithms",
  links: [
    { label: "Wikipedia", url: "https://en.wikipedia.org/wiki/Greedy_algorithm" },
  ]
};

const transformerResourceTree: TreeNode = {
  id: 'transformers',
  label: 'How Transformers Work',
  links: [
    { label: 'Attention Is All You Need (Original Paper)', url: 'https://arxiv.org/abs/1706.03762' },
  ],
    left: {
      id: 'anthropic',
      label: 'Anthropic Research',
      links: [
        { label: 'A Mathematical Framework for Transformer Circuits', url: 'https://transformer-circuits.pub/2021/framework/index.html' },
        { label: 'In-context Learning and Induction Heads', url: 'https://transformer-circuits.pub/2022/in-context-learning-and-induction-heads/index.html' },
        { label: 'Toy Models of Superposition', url: 'https://transformer-circuits.pub/2022/toy_model/index.html' },
      ],
    },
  right: {
    id: 'visualizations',
    label: 'Visualizations',
    links: [
      { label: 'Transformer Explainer (Interactive)', url: 'https://poloclub.github.io/transformer-explainer/' },
      { label: '3Blue1Brown Neural Networks Playlist', url: 'https://www.3blue1brown.com/topics/neural-networks' },
    ],
  },
};

const minimaxBotTree: TreeNode = {
  id: 'minimax',
  label: 'Minimax Algorithm',
  links: [
    { label: 'Chessprogramming: Minimax', url: 'https://www.chessprogramming.org/Minimax' },
    { label: 'Stanford CS: Minimax', url: 'https://cs.stanford.edu/people/eroberts/courses/soco/projects/2003-04/intelligent-search/minimax.html' },
    { label: 'Julia Chess AI Paper', url: 'https://www.researchgate.net/publication/376304826_Development_of_an_AI_for_the_Game_of_Chess' },
  ],
  left: {
    id: 'alpha-beta',
    label: 'Alpha-Beta & Move Ordering',
    links: [
      { label: 'Alpha-Beta Pruning', url: 'https://www.chessprogramming.org/Alpha-Beta' },
      { label: 'Pruning Techniques', url: 'https://www.chessprogramming.org/Pruning' },
      { label: 'Move Ordering', url: 'https://www.chessprogramming.org/Move_Ordering' },
      { label: 'Move Generation', url: 'https://www.chessprogramming.org/Move_Generation' },
    ],
  },
  right: {
    id: 'evaluation',
    label: 'Board Evaluation',
    links: [
      { label: 'Chessprogramming: Shogi', url: 'https://www.chessprogramming.org/Shogi' },
      { label: 'Chessprogramming: Evaluation', url: 'https://www.chessprogramming.org/Evaluation' },
      { label: 'Simplified Eval Function', url: 'https://www.chessprogramming.org/Simplified_Evaluation_Function' },
      { label: 'Shogi Piece Values (Paper)', url: 'https://link.springer.com/chapter/10.1007/978-3-319-09165-5_18' },
      { label: 'Learning Eval for Shogi (Paper)', url: 'https://link.springer.com/chapter/10.1007/978-3-540-30133-2_80' },
    ],
  },
};

const extraResourceTree: TreeNode = {
  id: "extra-resources",
  label: "The Bitter Lesson",
  links: [
    { label: "The Bitter Lesson", url: "http://www.incompleteideas.net/IncIdeas/BitterLesson.html" },
  ]
};

// ==================== MAIN COMPONENT ====================

function Bots() {
  return (
    <div className="bots-page">
      <header className="bots-header">
        <Link to="/" className="back-link">← Back to Game</Link>
        <h1>BitShogi Bots</h1>
        <p className="bots-subtitle">Choose your opponent</p>
      </header>

      <main className="bots-content">
        {/* Overview Section */}
        <section className="bots-section">
          <h2>Overview</h2>
          <p>
            Pick a challenger and explore the code. Different bots. Different brains.
          </p>
        </section>

        {/* Bot Cards */}
        <section className="bots-section">
          <h2>Available Bots</h2>
          
          <div className="bot-cards">
            {/* Random Bot */}
            <div className="bot-card">
              <div className="bot-card-header">
                <div className="bot-icon random">
                  <img src={RandomIcon} alt="Random bot" />
                </div>
                <div className="bot-title-area">
                  <h3>Random</h3>
                  <span className="bot-difficulty easy">Easy</span>
                </div>
              </div>
              <div className="bot-card-content">
                <p className="bot-description">
                  This was the first bot I could play against to get the engine up and running. There are a bunch of different
                  names, luck, chance, fortune, randomness, odds, probability, fate, coincidence, fluke, accident. Lets look into how this works a bit more.
                </p>
                <div className="bot-stats">
                  <div className="stat">
                    <span className="stat-label">Estimated Elo</span>
                    <span className="stat-value">~800</span>
                  </div>
                  <div className="stat">
                    <span className="stat-label">Response Time</span>
                    <span className="stat-value">Instant</span>
                  </div>
                </div>
                <div className="bot-details">
                  <h4 style={{ textDecoration: 'underline' }}>How it works:</h4>
                  
                  <p>
                    The Random bot gets a list of legal moves and randomly selects one using Julia's random number generator.
                  </p>

                  <h4>Move Selection</h4>
                  <SyntaxHighlighter 
                    language="julia" 
                    style={oneDark}
                    customStyle={{
                      borderRadius: '8px',
                      padding: '1rem',
                      fontSize: '0.9rem',
                    }}
                  >
                  {`function select_move(bot::RandomBot, game::GameState)::Union{Move, String}
    moves = get_legal_moves(game)
    if isempty(moves)
        return nothing
    end
    return moves[rand(bot.rng, 1:length(moves))]
end`}
                  </SyntaxHighlighter>
                  
                  <p>
                    After getting the list of legal moves, it calls <code>moves[rand(bot.rng, 1:length(moves))]</code> where 
                    a random integer is selected ranging from 1 to the number of available moves.
                  </p>

                  <h4>Bot Structure</h4>
                  <SyntaxHighlighter 
                    language="julia" 
                    style={oneDark}
                    customStyle={{
                      borderRadius: '8px',
                      padding: '1rem',
                      fontSize: '0.9rem',
                    }}
                  >
                    {`struct RandomBot <: Bot
    rng::AbstractRNG
end

RandomBot() = RandomBot(Random.default_rng())`}
                </SyntaxHighlighter>
                  <p>
                    The bot structure has an <code>rng</code> variable of type <code>AbstractRNG</code>, which is Julia's 
                    Random package's default random number generator.
                  </p>

                  <h4>Random Number Generation</h4>
                  <p>
                    Julia creates a numbered seed for each session to ensure reproducible randomness. To create that seed, 
                    Julia gathers OS-specific information attributed to being random:
                  </p>
                  <ul>
                    <li>Interrupt timing (keyboard, mouse, disk I/O, network packets)</li>
                    <li>Hardware random number generators (if available, like Intel's RDRAND)</li>
                    <li>CPU/GPU thermals</li>
                    <li>System scheduling timing</li>
                  </ul>

                  {/* Resource Tree */}
                  <ResourceTree tree={randomBotTree} />
                </div>
              </div>
            </div>

            {/* Greedy Bot */}
            <div className="bot-card">
              <div className="bot-card-header">
                <div className="bot-icon greedy">
                  <img src={GreedyIcon} alt="Greedy bot" />
                </div>
                <div className="bot-title-area">
                  <h3>Greedy</h3>
                  <span className="bot-difficulty easy">Easy</span>
                </div>
              </div>
              <div className="bot-card-content">
                <p className="bot-description">
                  As the name implies, it can't help itself. This bot eats pieces like an arcade kid eats quarters.
                </p>
                <div className="bot-stats">
                  <div className="stat">
                    <span className="stat-label">Estimated Elo</span>
                    <span className="stat-value">~1000</span>
                  </div>
                  <div className="stat">
                    <span className="stat-label">Response Time</span>
                    <span className="stat-value">Instant</span>
                  </div>
                </div>
                <div className="bot-details">
                  <h4>How it works:</h4>
                  <p>
                    The algorithm loops through all legal moves and sorts them into two buckets: captures and non-captures. 
                    For each capturing move, it looks up the target piece's value from PIECE_VALUES_BOT. If any captures exist, 
                    it sorts them by value (highest first) and returns the top pick. No captures? It falls back to a random non-capture move.
                  </p>
                  <SyntaxHighlighter 
                    language="julia" 
                    style={oneDark}
                    customStyle={{
                      borderRadius: '8px',
                      padding: '1rem',
                      fontSize: '0.9rem',
                    }}
                  >
                  {`for move in moves 
    captured = move_capture(move)
    if captured != NO_PIECE
        value = get(PIECE_VALUES_BOT, PieceType(captured), 0)
        push!(captures, (move, value))
    else
        push!(non_captures, move)
    end
end
if !isempty(captures)
    sort!(captures, by = x -> -x[2])
    return captures[1][1]
end

return non_captures[rand(bot.rng, 1:length(non_captures))]`}
                  </SyntaxHighlighter>
                  <h4>Piece Values</h4>
                  <table className="piece-values-table">
                    <thead>
                      <tr>
                        <th>Piece</th>
                        <th>Value</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr><td>Pawn</td><td>100</td></tr>
                      <tr><td>Lance</td><td>300</td></tr>
                      <tr><td>Knight</td><td>300</td></tr>
                      <tr><td>Silver</td><td>400</td></tr>
                      <tr><td>Gold or promote to Gold</td><td>500</td></tr>
                      <tr><td>Bishop</td><td>600</td></tr>
                      <tr><td>Rook</td><td>700</td></tr>
                      <tr><td>Promoted Bishop</td><td>800</td></tr>
                      <tr><td>Promoted Rook</td><td>900</td></tr>
                      <tr><td>King</td><td>10000</td></tr>
                    </tbody>
                  </table>

                  {/* <ResourceTree tree={greedyBotTree} /> */}
                   
                </div>
              </div>
            </div>

            {/* Claude Bot */}
            <div className="bot-card claude-card">
              <div className="bot-card-header">
                <div className="bot-icon claude">
                  <img src={ClaudeIcon} alt="Claude bot" />
                </div>
                <div className="bot-title-area">
                  <h3>Claude</h3>
                  <span className="bot-difficulty experimental">LLM Reasoning</span>
                </div>
              </div>
              <div className="bot-card-content">
                <p className="bot-description">
                This bot makes an API call to Claude Haiku. It's not the most advanced model, 
                but it's quick and we can see its reasoning. I think to fully understand the reasoning behind 
                Claude's decisions is to solve an open problem in Mechanistic Interpretability.</p>
                <div className="bot-stats">
                  <div className="stat">
                    <span className="stat-label">Estimated Elo</span>
                    <span className="stat-value">~1100-1300</span>
                  </div>
                  <div className="stat">
                    <span className="stat-label">Model</span>
                    <span className="stat-value">Haiku 4.5</span>
                  </div>
                  <div className="stat">
                    <span className="stat-label">Response Time</span>
                    <span className="stat-value">3-5s</span>
                  </div>
                </div>
                <div className="bot-details">
                  <h4>About:</h4>
                    <p>
                      I've added the 
                      ability to see its thinking when you play against it. One issue is that Claude is 
                      trained more on chess than shogi. Standard FEN notation for chess uses lowercase=Black 
                      and uppercase=White, but SFEN (for Shogi) uses the opposite: lowercase=White and 
                      uppercase=Black. So sometimes Claude gets mixed up on strategy, but it always chooses from 
                      a list of legal moves. I've tried to remove color specifics in the prompt as well. It's 
                      interesting to see its reasoning behind moves though.
                  </p>
                  <h4>Excerpt from Reasoning Display</h4>
                  <div>
                    <p><strong>The best move appears to be 1b2d+ because:</strong></p>
                    <ol>
                      <li>It moves my knight from 1b to 2d with promotion, giving check to the enemy king at 2a</li>
                      <li>This is a forcing move that puts immediate pressure on the enemy</li>
                      <li>Promoting the knight increases its power significantly</li>
                      <li>This creates a strong attacking position where the enemy must respond to the check</li>
                    </ol>
                  </div>
                  <h4>Prompt</h4>
                  <SyntaxHighlighter 
                    language="julia" 
                    style={oneDark}
                    customStyle={{
                      borderRadius: '8px',
                      padding: '1rem',
                      fontSize: '0.9rem',
                    }}
                  >
                  {`prompt = """You are playing minishogi (5x5 Japanese chess).

  CRITICAL - PIECE IDENTIFICATION:
  - YOUR pieces are LOWERCASE: k, g, s, r, b, p, l, n
  - OPPONENT pieces are UPPERCASE: K, G, S, R, B, P, L, N
  - If you see an UPPERCASE letter, that is the ENEMY piece, not yours!
  - UPPERCASE pieces are ENEMY pieces you can capture!
  - If you see a lowercase letter, that is YOUR piece.

  Current position (SFEN): $sfen

  Your legal moves: $(join(legal_moves, ", "))

  Move notation:
  - Board moves: "1a2b" = move piece FROM 1a TO 2b
  - Promotions: "1a2b+" = move and promote
  - Drops: "p*3c" = drop a pawn from your hand onto 3c

  SFEN board explanation:
  - Format: <board>/<board>/... <turn> <hands> <move#>
  - Ranks go a (top) to e (bottom), files go 1 (left) to 5 (right)
  - "w" = your turn, "b" = opponent's turn
  - In the hand section: lowercase = YOUR hand, UPPERCASE = opponent's hand

  First, identify where YOUR pieces (lowercase) are located.
  Then identify where OPPONENT pieces (UPPERCASE) are located.
  Look for captures, checks, and threats.

  Explain your thinking briefly (2-3 paragraphs), then choose your move.
  End with exactly: MOVE: <your chosen move>"""`}
                  </SyntaxHighlighter>
                </div>
                <ResourceTree tree={transformerResourceTree} />
              </div>
            </div>

            {/* Minimax Bot */}
            <div className="bot-card minimax-card">
              <div className="bot-card-header">
                <div className="bot-icon minimax">
                  <img src={MinimaxIcon} alt="Minimax bot" />
                </div>
                <div className="bot-title-area">
                  <h3>Minimax</h3>
                  <div className = "bot-difficulty-tags">
                    <span className="bot-difficulty medium">Medium</span>
                    <span className="bot-difficulty hard">Hard</span>
                  </div>
                </div>
              </div>
              <div className="bot-card-content">
                <p className="bot-description">
                  Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do 
                  eiusmod tempor incididunt ut labore et dolore magna aliqua.
                </p>
                <div className="bot-stats">
                  <div className="stat">
                    <span className="stat-label">Estimated Elo</span>
                    <span className="stat-value">~1400-1600</span>
                  </div>
                  <div className="stat">
                    <span className="stat-label">Search Depth</span>
                    <span className="stat-value">5 ply</span>
                  </div>
                  <div className="stat">
                    <span className="stat-label">Response Time</span>
                    <span className="stat-value">1-2s</span>
                  </div>
                </div>
                <div className="bot-details">
                  <h4>How it works</h4>
                  <p>
                    Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam 
                    auctor, nisl eget ultricies tincidunt, nisl nisl aliquam nisl.
                  </p>
                  <h4>Alpha-Beta Pruning</h4>
                  <p>
                    Lorem ipsum dolor sit amet, consectetur adipiscing elit. Vestibulum 
                    ante ipsum primis in faucibus orci luctus et ultrices.
                  </p>
                  <h4>Move Ordering</h4>
                  <p>
                    Lorem ipsum dolor sit amet, consectetur adipiscing elit. Praesent 
                    commodo cursus magna, vel scelerisque nisl consectetur.
                  </p>
                </div>
              </div>

              <ResourceTree tree={minimaxBotTree} />
            </div>

          </div>
        </section>

        {/* Comparison Table */}
        <section className="bots-section">
          <h2>Comparison</h2>
          <table className="comparison-table">
            <thead>
              <tr>
                <th>Bot</th>
                <th>Strength</th>
                <th>Speed</th>
                <th>Style</th>
                <th>Best For</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td>Random</td>
                <td>~800 Elo</td>
                <td>Instant</td>
                <td>Chaotic</td>
                <td>Testing the website during development</td>
              </tr>
              <tr>
                <td>Greedy</td>
                <td>~1000 Elo</td>
                <td>Instant</td>
                <td>Materialistic</td>
                <td>See a greedy algorithm in action</td>
              </tr>
              <tr>
                <td>Claude</td>
                <td>~1100-1300 Elo</td>
                <td>3-5s</td>
                <td>LLM Reasoning</td>
                <td>Seeing how LLMs reason for games</td>
              </tr>
              <tr>
                <td>Minimax</td>
                <td>~1400-1600 Elo</td>
                <td>1-2s</td>
                <td>Tactical</td>
                <td>A real challenge</td>
              </tr>
            </tbody>
          </table>
        </section>

        {/* Future Plans */}
        <section className="bots-section">
          <h2>Future Plans</h2>
          <p>
            These are some directions I'm thinking about taking this project now that I have a fun looking UI and the game engine setup.
          </p>
          <ul>
            <li>Make a reinforcement learning bot with ReinforcementLearning.jl </li>
            <li>Make the bots play each other and put up a scoreboard (over 1000 games)</li>
            <li>Keep claude's reasoning in one box so we can see it develop a strategy throughout the game</li>
            <li>Implement my own model and see if I can learn more about how different structures play differently</li>
            <li>Simple play against other players, have a shared keyword per game, I play with my keyword and its saved, then when someone else uses the same
              keyword then that same game is loaded with the most recent board state.
            </li>
            <li>Undo button</li>
            <li>Game ends when repeitive draw - current task</li>
          </ul>

          <ResourceTree tree={extraResourceTree} />
        </section>
      </main>

      <footer className="bots-footer">
        <Link to="/">← Back to Game</Link>
      </footer>
    </div>
  );
}

export default Bots;