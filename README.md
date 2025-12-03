## BitShogi - "The Game of Generals"

> **BitShogi, playing a little bit every day using bitboards.**

A chess-like game engine implemented in Julia.

<!-- ### Roadmap
* **Lean Verifications:** Formal verification practice of game logic using Lean 4
* **Pleasant UI:** Readable game pieces UI/UX
* **Daily Board Setups:** Non-trivial daily board setups (High Branching Factor?)
* **Game Database:** Need saved games to train on later down the line
* **Bot Variety:** Additional simple strategy bots with description of what move they made
* **A bot that learns:** NNUE or RL models -->
'''mermaid
timeline
    title BitShogi Development Path
    Current Focus
        : Lean Verifications
        : Pleasant UI
    Upcoming Features
        : Daily Challenges (Branching Mates)
        : Game Database (Save/Load)
    Future Goals
        : Bot Variety & Personalities
        : Advanced AI (NNUE/RL Models)
'''

### Background Resources
* **Shogi Rules:** [Wikipedia - Minishogi](https://en.wikipedia.org/wiki/Minishogi) | [Shogi Harbour](https://shogiharbour.com/)
* **Chess & Bitboards:** [Chess Programming Wiki - Bitboards](https://www.chessprogramming.org/Bitboards)
* **Protocols:** [USI (Universal Shogi Interface) Protocol](https://www.chessprogramming.org/USI)
* **Engine Dev:** [Computer Shogi Association](http://www2.computer-shogi.org/protocol/)

### Project Structure
* **`BitShogi/src`**: Core game logic (Julia). Implements bitboards, move generation, and validation.
* **`BitShogi/server`**: REST API server handling game state and bot moves.
* **`BitShogi/frontend`**: Interactive web interface for playing against the engine.
* **`Shogi_lean`**: Formal verification and proofs of game logic.

### Tech Stack
* **Backend:** [Julia 1.11](https://julialang.org/) (HTTP.jl, JSON3.jl)
* **Frontend:** [React](https://react.dev/) + [TypeScript](https://www.typescriptlang.org/) (Vite)
* **Verification:** [Lean 4](https://leanprover.github.io/)
* **Infrastructure:** Docker & Docker Compose