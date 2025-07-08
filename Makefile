# Makefile for RxInferKServe.jl

# Julia executable
JULIA ?= julia

# Project directory
PROJECT_DIR := $(shell pwd)

# Default target
.PHONY: all
all: deps build test

# Install dependencies
.PHONY: deps
deps:
	@echo "Installing Julia dependencies..."
	$(JULIA) --project=. -e 'using Pkg; Pkg.instantiate()'

# Update dependencies
.PHONY: update
update:
	@echo "Updating Julia dependencies..."
	$(JULIA) --project=. -e 'using Pkg; Pkg.update()'

# Build the project (precompile)
.PHONY: build
build: deps
	@echo "Building RxInferKServe..."
	$(JULIA) --project=. -e 'using Pkg; Pkg.build()'
	$(JULIA) --project=. -e 'using RxInferKServe'

# Build optimized system image
.PHONY: sysimage
sysimage: deps
	@echo "Building optimized system image..."
	$(JULIA) --project=. scripts/build_sysimage.jl

# Generate protobuf files
.PHONY: proto
proto:
	@echo "Generating protobuf files..."
	$(JULIA) --project=. -e 'using ProtoBuf; ProtoBuf.protojl(["kserve/v2/inference.proto"], "proto", "src/grpc")'

# Run tests
.PHONY: test
test: build
	@echo "Running tests..."
	$(JULIA) --project=. -e 'using Pkg; Pkg.test()'

# Run specific test file
.PHONY: test-file
test-file: build
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make test-file FILE=test_server.jl"; \
		exit 1; \
	fi
	@echo "Running test file: $(FILE)"
	$(JULIA) --project=. -e 'using Test; include("test/$(FILE)")'

# Run linting/code quality checks
.PHONY: lint
lint:
	@echo "Running code quality checks with Aqua.jl..."
	$(JULIA) --project=. -e 'using Pkg; Pkg.add("Aqua"); using Aqua; Aqua.test_all(RxInferKServe)'

# Format code
.PHONY: format
format:
	@echo "Formatting Julia code..."
	$(JULIA) --project=. -e 'using Pkg; Pkg.add("JuliaFormatter"); using JuliaFormatter; format("src", verbose=true); format("test", verbose=true)'

# Clean build artifacts
.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	rm -rf Manifest.toml
	rm -rf rxinfer_server.so
	rm -rf .julia
	find . -name "*.cov" -delete
	find . -name "*.mem" -delete

# Deep clean (including dependencies)
.PHONY: distclean
distclean: clean
	@echo "Deep cleaning..."
	rm -rf docs/build
	rm -rf deps/build.log

# Start the server
.PHONY: server
server: build
	@echo "Starting RxInferKServe..."
	$(JULIA) --project=. -e 'using RxInferKServe; start_server()'

# Start server with custom options
.PHONY: server-dev
server-dev: build
	@echo "Starting RxInferKServe in development mode..."
	$(JULIA) --project=. -e 'using RxInferKServe; start_server(host="0.0.0.0", port=8080, grpc_port=8081, log_level="debug")'

# Start server with optimized system image
.PHONY: server-prod
server-prod: sysimage
	@echo "Starting RxInferKServe with optimized image..."
	$(JULIA) --sysimage=rxinfer_server.so --project=. -e 'using RxInferKServe; start_server()'

# Run REPL with project
.PHONY: repl
repl: deps
	@echo "Starting Julia REPL with project..."
	$(JULIA) --project=. -i -e 'using RxInferKServe'

# Generate documentation
.PHONY: docs
docs:
	@echo "Generating documentation..."
	$(JULIA) --project=docs -e 'using Pkg; Pkg.instantiate(); include("docs/make.jl")'

# Serve documentation locally
.PHONY: docs-serve
docs-serve: docs
	@echo "Serving documentation at http://localhost:8000"
	cd docs/build && python3 -m http.server 8000

# Format code with JuliaFormatter
.PHONY: format
format:
	@echo "Formatting Julia code..."
	@$(JULIA) -e 'using Pkg; Pkg.add("JuliaFormatter")' 2>/dev/null || true
	@$(JULIA) -e 'using JuliaFormatter; format(".", verbose=true)'

# Check Julia version
.PHONY: check-julia
check-julia:
	@echo "Julia version:"
	@$(JULIA) --version
	@echo ""
	@echo "Project status:"
	@$(JULIA) --project=. -e 'using Pkg; Pkg.status()'

# Run benchmarks
.PHONY: bench
bench: build
	@echo "Running benchmarks..."
	$(JULIA) --project=. -e 'include("benchmark/benchmarks.jl")'

# Create a release build
.PHONY: release
release: clean deps build test
	@echo "Creating release build..."
	@echo "Version: $$($(JULIA) --project=. -e 'using Pkg; println(Pkg.project().version)')"
	@echo "All tests passed. Ready for release!"

# Docker targets
.PHONY: docker-build
docker-build:
	@echo "Building Docker image..."
	docker build -t rxinfer-mlserver:latest -f docker/Dockerfile .

.PHONY: docker-run
docker-run:
	@echo "Running Docker container..."
	docker run -p 8080:8080 -p 8081:8081 rxinfer-mlserver:latest

# Help target
.PHONY: help
help:
	@echo "RxInferKServe.jl Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  all          - Install deps, build, and test (default)"
	@echo "  deps         - Install Julia dependencies"
	@echo "  update       - Update Julia dependencies"
	@echo "  build        - Build/precompile the project"
	@echo "  sysimage     - Build optimized system image"
	@echo "  proto        - Generate protobuf files"
	@echo "  test         - Run all tests"
	@echo "  test-file    - Run specific test file (FILE=name.jl)"
	@echo "  lint         - Run code quality checks"
	@echo "  format       - Format code with JuliaFormatter"
	@echo "  clean        - Remove build artifacts"
	@echo "  distclean    - Deep clean (including deps)"
	@echo "  server       - Start the server"
	@echo "  server-dev   - Start server in dev mode"
	@echo "  server-prod  - Start server with sysimage"
	@echo "  repl         - Start Julia REPL with project"
	@echo "  docs         - Generate documentation"
	@echo "  docs-serve   - Serve docs locally"
	@echo "  check-julia  - Check Julia version and project status"
	@echo "  bench        - Run benchmarks"
	@echo "  release      - Create a release build"
	@echo "  docker-build - Build Docker image"
	@echo "  docker-run   - Run Docker container"
	@echo "  help         - Show this help message"

# Declare all targets as PHONY to ensure they always run
.PHONY: all deps update build sysimage proto test test-file lint format \
        clean distclean server server-dev server-prod repl docs docs-serve \
        check-julia bench release docker-build docker-run help