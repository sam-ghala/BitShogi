# Dockerfile for BitShogi Julia backend
FROM julia:1.11-bookworm

WORKDIR /app

# Install Julia packages
COPY Project.toml .
# Copy source code
COPY src/ ./src/
RUN julia -e 'using Pkg; Pkg.activate("."); Pkg.instantiate()'

# Pre-compile packages
RUN julia -e 'using Pkg; Pkg.activate("."); using HTTP, JSON3, Random'


COPY server/ ./server/

# Expose port
EXPOSE 8000

# Run server
CMD ["julia", "--project=.", "server/server.jl"]
