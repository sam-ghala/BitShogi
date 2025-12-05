## BitShogi - "The Game of Generals"

> **BitShogi, playing a little bit every day using bitboards.**

Play at [bitshogi.com](bitshogi.com)

Hi, I'm working on a chess-like game engine implemented in Julia. Credit for getting all the UI design done goes to Claude. Now that its playable, I'm working on creating a bot that can beat me. If you want to contribute or have any ideas or comments then open an issue or make a pull request. Thank you.

### Roadmap
* **A bot that can beat me:** NNUE, RL, Transformer, minimax - CURRENT TASK

### Some Resources I've found along the way
* **Shogi Rules:** [Wikipedia - Minishogi](https://en.wikipedia.org/wiki/Minishogi) | [Shogi Harbour](https://shogiharbour.com/)
* **Chess & Bitboards:** [Chess Programming Wiki - Bitboards](https://www.chessprogramming.org/Bitboards)
* **Protocols:** [USI (Universal Shogi Interface) Protocol](https://www.chessprogramming.org/USI)
* **Engine Dev:** [Computer Shogi Association](http://www2.computer-shogi.org/protocol/)
* **ML Chess:** [Mastering Chess with a Transformer Model](https://arxiv.org/abs/2409.12272)
* **Shogi SFEN Notation:** [Shogi_Evaluation_Function_Using_Genetic_Algorithms](https://www.researchgate.net/publication/384972282_Learning_a_Shogi_Evaluation_Function_Using_Genetic_Algorithms#pf2)

### Project Structure
* **`BitShogi/src`**: Core game logic (Julia). Implements bitboards, move generation, and validation.
* **`BitShogi/server`**: REST API server handling game state and bot moves.
* **`BitShogi/frontend`**: Interactive web interface for playing against the engine.
* **`Shogi_lean`**: Formal verification and proofs of game logic. Just to practice my lean.

### Tech Stack
* **Engine:** [Julia 1.11](https://julialang.org/) (HTTP.jl, JSON3.jl)
* **Frontend:** [React](https://react.dev/) + [TypeScript](https://www.typescriptlang.org/) (Vite)
* **Verification:** [Lean 4](https://leanprover.github.io/)
* **Infrastructure:** Docker, [Railway](https://railway.app/) (backend), [Vercel](https://vercel.com/) (frontend)
* [SVG file design website](https://www.svgviewer.dev/)


> [!TIP]
> Run loadRandomPuzzle() in the console for another puzzle.