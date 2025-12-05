import { Link } from 'react-router-dom';
import './Bots.css';

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
            Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod 
            tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, 
            quis nostrud exercitation ullamco laboris.
          </p>
        </section>

        {/* Bot Cards */}
        <section className="bots-section">
          <h2>Available Bots</h2>
          
          <div className="bot-cards">
            {/* Random Bot */}
            <div className="bot-card">
              <div className="bot-card-header">
                <div className="bot-icon random">🎲</div>
                <div className="bot-title-area">
                  <h3>Random</h3>
                  <span className="bot-difficulty easy">Easy</span>
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
                    <span className="stat-value">~800</span>
                  </div>
                  <div className="stat">
                    <span className="stat-label">Response Time</span>
                    <span className="stat-value">Instant</span>
                  </div>
                </div>
                <div className="bot-details">
                  <h4>How it works</h4>
                  <p>
                    Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam 
                    auctor, nisl eget ultricies tincidunt, nisl nisl aliquam nisl.
                  </p>
                </div>
              </div>
            </div>

            {/* Greedy Bot */}
            <div className="bot-card">
              <div className="bot-card-header">
                <div className="bot-icon greedy">💰</div>
                <div className="bot-title-area">
                  <h3>Greedy</h3>
                  <span className="bot-difficulty easy">Easy</span>
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
                    <span className="stat-value">~1000</span>
                  </div>
                  <div className="stat">
                    <span className="stat-label">Response Time</span>
                    <span className="stat-value">Instant</span>
                  </div>
                </div>
                <div className="bot-details">
                  <h4>How it works</h4>
                  <p>
                    Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam 
                    auctor, nisl eget ultricies tincidunt, nisl nisl aliquam nisl.
                  </p>
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
                      <tr><td>Gold</td><td>500</td></tr>
                      <tr><td>Bishop</td><td>600</td></tr>
                      <tr><td>Rook</td><td>700</td></tr>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>

            {/* Minimax Bot */}
            <div className="bot-card">
              <div className="bot-card-header">
                <div className="bot-icon minimax">🧠</div>
                <div className="bot-title-area">
                  <h3>Minimax</h3>
                  <span className="bot-difficulty medium">Medium</span>
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
            </div>

            {/* Claude Bot */}
            <div className="bot-card claude-card">
              <div className="bot-card-header">
                <div className="bot-icon claude">🤖</div>
                <div className="bot-title-area">
                  <h3>Claude</h3>
                  <span className="bot-difficulty experimental">Experimental</span>
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
                  <h4>How it works</h4>
                  <p>
                    Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam 
                    auctor, nisl eget ultricies tincidunt, nisl nisl aliquam nisl.
                  </p>
                  <h4>Reasoning Display</h4>
                  <p>
                    Lorem ipsum dolor sit amet, consectetur adipiscing elit. Vestibulum 
                    ante ipsum primis in faucibus orci luctus et ultrices.
                  </p>
                  <h4>Limitations</h4>
                  <p>
                    Lorem ipsum dolor sit amet, consectetur adipiscing elit. Praesent 
                    commodo cursus magna, vel scelerisque nisl consectetur.
                  </p>
                </div>
              </div>
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
                <td>Lorem ipsum</td>
              </tr>
              <tr>
                <td>Greedy</td>
                <td>~1000 Elo</td>
                <td>Instant</td>
                <td>Materialistic</td>
                <td>Lorem ipsum</td>
              </tr>
              <tr>
                <td>Minimax</td>
                <td>~1400-1600 Elo</td>
                <td>1-2s</td>
                <td>Tactical</td>
                <td>Lorem ipsum</td>
              </tr>
              <tr>
                <td>Claude</td>
                <td>~1100-1300 Elo</td>
                <td>3-5s</td>
                <td>Intuitive</td>
                <td>Lorem ipsum</td>
              </tr>
            </tbody>
          </table>
        </section>

        {/* Future Plans */}
        <section className="bots-section">
          <h2>Future Plans</h2>
          <p>
            Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod 
            tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam.
          </p>
          <ul>
            <li>Lorem ipsum dolor sit amet</li>
            <li>Consectetur adipiscing elit</li>
            <li>Sed do eiusmod tempor incididunt</li>
            <li>Ut labore et dolore magna aliqua</li>
          </ul>
        </section>
      </main>

      <footer className="bots-footer">
        <Link to="/">← Back to Game</Link>
      </footer>
    </div>
  );
}

export default Bots;