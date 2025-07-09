# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- GitHub Actions CI/CD pipeline with:
  - Automated testing across Julia 1.9, 1.10, 1.11, and nightly
  - Code coverage reporting with Codecov
  - System image building and testing
  - Code formatting checks with JuliaFormatter
- Semantic versioning with conventional commits
- Automated releases with semantic-release
- Docker image building and publishing to GitHub Container Registry (ghcr.io)
- Multi-architecture Docker support (amd64, arm64)
- Container vulnerability scanning with Trivy
- Documentation building and deployment to GitHub Pages
- Dependabot configuration for automated dependency updates
- Pull request and issue templates

### Changed
- Migrated to KServe v2 inference protocol
- Removed v1 API backward compatibility
- Updated HTTP endpoints to use `/v2` prefix
- Implemented full gRPC support on default port 8081
- Updated client libraries for v2 compatibility

### Fixed
- Fixed model inference to use keyword arguments for RxInfer compatibility
- Fixed serialization of inference results with proper key conversion
- Fixed client test suite with correct function imports
- Fixed gRPC server protobuf type constructors
- Fixed registry test scoping issues with @model macro

### Technical Details
- Models now use keyword arguments when called by RxInfer.infer
- Serialization properly handles Symbol to String key conversion
- gRPC server correctly handles parameter type conversions
- Test suite properly imports unexported functions

## [0.1.0] - Initial Release

### Added
- RxInfer.jl model serving through REST API
- KServe v2 inference protocol support
- Julia and Python client libraries
- Docker deployment with docker-compose
- System image compilation for fast startup
- Model registry with instance management
- Comprehensive test suite
- API documentation
- Health check endpoints
- CORS and authentication middleware
- Structured logging
- Prometheus metrics support

[Unreleased]: https://github.com/pteradigm/RxInferKServe.jl/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/pteradigm/RxInferKServe.jl/releases/tag/v0.1.0