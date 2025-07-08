# Multi-stage build for RxInferKServe
FROM julia:1.11-bullseye AS builder

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set up working directory
WORKDIR /app

# Copy project files
COPY Project.toml Manifest.toml ./
COPY src/ ./src/
COPY scripts/ ./scripts/

# Install Julia packages
RUN julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'

# Build system image for faster startup
RUN julia --project=. scripts/build_sysimage.jl

# Runtime stage
FROM julia:1.11-bullseye

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 1000 rxinfer

# Set up working directory
WORKDIR /app

# Copy from builder
COPY --from=builder /app /app
COPY --from=builder /root/.julia /home/rxinfer/.julia

# Note: Proto files are only needed for development, not runtime

# Set ownership
RUN chown -R rxinfer:rxinfer /app /home/rxinfer/.julia

# Switch to non-root user
USER rxinfer

# Environment variables
ENV JULIA_PROJECT=/app
ENV JULIA_DEPOT_PATH=/home/rxinfer/.julia
ENV JULIA_SYSIMAGE=/app/rxinfer_server.so
ENV JULIA_NUM_THREADS=auto

# Expose ports
EXPOSE 8080 8081

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD julia --sysimage=$JULIA_SYSIMAGE -e 'using HTTP; HTTP.get("http://localhost:8080/v2/health/ready")' || exit 1

# Default command
CMD ["julia", "--sysimage=/app/rxinfer_server.so", "-e", "using RxInferKServe; start_server(host=\"0.0.0.0\", port=8080)"]