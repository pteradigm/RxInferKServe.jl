# RULES.md

This file provides guidance to Claude Code (claude.ai/code), Cline, and will be used with other agenst when working with code in this repository.

## Essential Commands

### Testing
```bash
# Run full test suite with code quality checks
julia --project=. -e 'using Pkg; Pkg.test()'

# Run tests from REPL
julia> using Pkg; Pkg.test("RxInferKServe")
```

### Building
```bash
# Build optimized system image for fast startup (reduces 22s to <1s)
julia --project=. scripts/build_sysimage.jl

# Use the optimized image
julia --sysimage=rxinfer-kserve.so --project=.
```

### Running the Server
```julia
using RxInferKServe
start_server(host="0.0.0.0", port=8080)
```

### Docker Deployment
```bash
cd docker && docker-compose up
```

## Architecture Overview

RxInferKServe.jl serves RxInfer.jl probabilistic models through REST APIs with MLServer integration. The architecture follows a client-server model with clean separation of concerns:

1. **Model Layer** (`src/models/`) - RxInfer.jl probabilistic models wrapped with metadata
2. **Registry Layer** (`src/models/registry.jl`) - Manages model lifecycle and instances with UUIDs
3. **Serialization Layer** (`src/serialization.jl`) - Converts probabilistic distributions to/from JSON using JSON3.jl and StructTypes
4. **HTTP Layer** (`src/server/`) - RESTful API with composable middleware pipeline (auth, CORS, logging, errors)
5. **Client Layer** (`src/client/`, `python/`) - Language-specific clients (Julia and Python)

### Key Architectural Patterns

- **Middleware Pipeline**: Composable request handling in `src/server/middleware.jl`
- **Model Registry**: Centralized model management with instance tracking
- **Adapter Pattern**: Wraps RxInfer models for HTTP serving in `src/models/base.jl`
- **Multi-process Scaling**: Handles Julia's single-threaded HTTP limitation through process pools

### API Structure

All endpoints follow OpenAPI 3.0 compliance under `/v1/`:
- `GET /v1/health` - Health check
- `GET /v1/models` - List available models
- `POST /v1/models/instances` - Create model instance
- `POST /v1/models/instances/{id}/infer` - Run inference
- `DELETE /v1/models/instances/{id}` - Delete instance

## Working with Models

Models use the standard RxInfer `@model` macro and are registered through:

```julia
using RxInfer

@model function custom_model(x, y)
    θ ~ Beta(1.0, 1.0)
    for i in 1:length(y)
        y[i] ~ Normal(θ * x[i], 1.0)
    end
end

register_model("custom_model", custom_model, version="1.0.0")
```

## Production Considerations

1. **Startup Time**: Always use PackageCompiler.jl sysimages in production
2. **Concurrency**: Deploy multiple Julia processes behind a load balancer (HTTP.jl is single-threaded)
3. **Memory**: Set `JULIA_GC_THREADS` for multi-threaded garbage collection
4. **Monitoring**: Use structured logging and `/health` endpoint

## Task Management

The `tasks/` directory contains a structured task management system. Task files follow the naming convention `TASK-XXXX-YY-ZZ` with comprehensive specifications and implementation tracking.

## Development Workflow

1. Make changes to source files in `src/`
2. Run tests to ensure nothing breaks
3. For performance-critical changes, rebuild the sysimage
4. Test with both Julia and Python clients
5. Update API documentation if endpoints change

## Dependencies

- **HTTP.jl**: Web server framework
- **JSON3.jl + StructTypes.jl**: High-performance JSON serialization
- **RxInfer.jl**: Probabilistic programming engine
- **Logging.jl**: Structured logging
- **UUIDs.jl**: Unique identifiers for model instances

## Code Quality

The project uses Aqua.jl for code quality checks, integrated into the test suite. This checks for:
- Method ambiguities
- Unbound type parameters
- Invalid exports
- Piracy detection
- Project consistency

Note: Some checks are disabled due to upstream dependencies (ambiguities in RxInfer).

## Claude Code Guidance

- **Implementation Strategy**: 
  * Refer to both the documentation and the source of RxInfer and RxInferServer when generating implementations.