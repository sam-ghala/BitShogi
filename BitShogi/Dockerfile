# Dockerfile for BitShogi Julia backend
FROM julia:1.10-bookworm

WORKDIR /app

# Install Julia packages
COPY Project.toml .
RUN julia -e 'using Pkg; Pkg.activate("."); Pkg.instantiate()'

# Pre-compile packages
RUN julia -e 'using Pkg; Pkg.activate("."); using HTTP, JSON3, Random'

# Copy source code
COPY src/ ./src/
COPY server/ ./server/

# Expose port
EXPOSE 8000

# Run server
CMD ["julia", "--project=.", "server/server.jl"]
