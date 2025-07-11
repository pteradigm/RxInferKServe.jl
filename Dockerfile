# Multi-stage build for RxInferKServe
FROM julia:1.11-bullseye AS builder

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set up working directory
WORKDIR /app

# First, copy only the files needed for package installation
# This allows Docker to cache the package installation layer
COPY Project.toml Manifest.toml ./

# Install Julia packages (this layer will be cached if Project.toml/Manifest.toml don't change)
# Note: We can't precompile yet because RxInferKServe source isn't available
RUN julia --project=. -e 'using Pkg; Pkg.instantiate()'

# Now copy the source code
COPY src/ ./src/
COPY scripts/ ./scripts/

# Precompile after source is available
RUN julia --project=. -e 'using Pkg; Pkg.precompile()'

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

# Create directories for model mounting
RUN mkdir -p /app/models /app/config

# Set ownership
RUN chown -R rxinfer:rxinfer /app /home/rxinfer/.julia

# Switch to non-root user
USER rxinfer

# Environment variables
ENV JULIA_PROJECT=/app
ENV JULIA_DEPOT_PATH=/home/rxinfer/.julia
ENV JULIA_SYSIMAGE=/app/rxinfer-kserve.so
ENV JULIA_NUM_THREADS=auto
ENV RXINFER_MODEL_PATH=/app/models
ENV RXINFER_CONFIG_PATH=/app/config

# Expose ports
EXPOSE 8080 8081

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD julia --sysimage=$JULIA_SYSIMAGE -e 'using HTTP; HTTP.get("http://localhost:8080/v2/health/ready")' || exit 1

# Default command
CMD ["julia", "--sysimage=/app/rxinfer-kserve.so", "-e", "using RxInferKServe; start_server(host=\"0.0.0.0\", port=8080)"]