# Unified CI/CD Strategy

This document outlines our consistent 3-workflow CI/CD strategy for all repositories in the organization.

## Overview

We've standardized on a **3-workflow pattern** that provides clear separation of concerns:

1. **CI Workflow** - Code quality validation and testing
2. **Release Workflow** - Automated semantic releases and artifact publishing  
3. **Documentation Workflow** - Documentation building and deployment

## Workflow Structure

### 1. CI Workflow (`ci.yml`)

**Purpose**: Validate code quality and functionality before merge
**Triggers**: `push` and `pull_request` on `main` branch
**Platform Focus**: `linux/amd64` (expandable to multi-arch later)

**Job Dependencies**:
```
lint (runs first)
├── test (depends on lint)
├── build (depends on lint)
└── docker-build (depends on test + build)
```

**Key Features**:
- **Fail Fast**: Lint job runs first, others depend on it
- **Parallel Execution**: Test and build run in parallel after lint passes
- **Docker Validation**: Builds container image without pushing (validation only)
- **Artifact Upload**: Uploads build artifacts for release workflow

### 2. Release Workflow (`release.yml`)

**Purpose**: Automated releases and artifact publishing
**Triggers**: `workflow_run` dependency on CI workflow success
**Safety**: Only runs after CI workflow completes successfully

**Job Dependencies**:
```
release (semantic versioning)
└── docker (build & push images - only if new release)
```

**Key Features**:
- **Workflow Dependency**: Waits for CI success before running
- **Semantic Release**: Automated versioning based on conventional commits
- **Conditional Publishing**: Only publishes if new release is created
- **Container Registry**: Publishes to GitHub Container Registry (GHCR)
- **No Registry Publishing**: Removed Julia/Go registry publishing per requirements

### 3. Documentation Workflow (`docs.yml`)

**Purpose**: Build and deploy documentation
**Triggers**: `push` to `main`, `pull_request`, tags, manual dispatch
**Deployment**: GitHub Pages for main branch and tags only

**Job Dependencies**:
```
build (generate docs)
└── deploy (publish to GitHub Pages - main/tags only)
```

## Language-Specific Adaptations

### Julia Projects

**CI Workflow**:
- **Lint**: JuliaFormatter code quality checks
- **Test**: Multi-platform testing with multiple Julia versions
- **Build**: System image compilation for performance optimization
- **Docker Build**: Container validation

**Release Workflow**:
- **Semantic Release**: Updates Project.toml version, creates changelog
- **Docker**: Container publishing to registry
- **Artifacts**: System image files attached to GitHub releases

**Documentation**:
- **Documenter.jl**: Full documentation system with doctests
- **GitHub Pages**: Automated deployment

### Go Projects

**CI Workflow**:
- **Lint**: Go formatting (gofmt, goimports, gofumpt), go vet, conventional commits
- **Test**: Unit tests with coverage reporting
- **Build**: Binary compilation with build tools
- **Integration Test**: Service integration testing
- **Docker Build**: Container validation

**Release Workflow**:
- **Semantic Release**: Creates changelog, tags releases
- **Docker**: Container publishing to registry
- **Artifacts**: Compiled binaries attached to GitHub releases

**Documentation**:
- **Go Doc**: API documentation generation
- **Static Site**: Documentation site generation
- **GitHub Pages**: Automated deployment

### Other Languages

This strategy can be adapted for any language by:
1. Replacing language-specific linting tools
2. Adapting test frameworks and build processes
3. Configuring appropriate package managers and registries
4. Setting up language-specific documentation tools

## Key Improvements Made

### Consistency Across Projects
1. **Standardized Job Names**: lint, test, build, docker-build/docker
2. **Unified Triggers**: Same trigger patterns across workflows
3. **Consistent Dependencies**: Same job dependency structure
4. **Platform Focus**: linux/amd64 standardization

### Safety and Reliability
1. **Workflow Dependencies**: Release only runs after CI success
2. **Fail Fast**: Lint failures prevent other jobs from running
3. **Conditional Publishing**: Only publish on actual releases
4. **Concurrency Control**: Cancel old runs to save resources

### Removed Complexity
1. **Registry Publishing**: Removed Julia General Registry and Go module publishing
2. **Consolidated Docker**: Merged standalone docker.yml into CI and Release
3. **Simplified Semantic Release**: Removed Docker from exec plugin

## Configuration Files

### Semantic Release (`.releaserc.json`)
Both projects use consistent conventional commit rules:
- `feat:` → minor version bump
- `fix:`, `perf:`, `refactor:` → patch version bump  
- `BREAKING CHANGE:` → major version bump
- `docs:`, `test:`, `ci:`, `chore:` → no release

### Docker Strategy
- **CI**: Build image with `test` tag (validation only)
- **Release**: Build and push with semantic version tags + `latest`
- **Platform**: linux/amd64 (ready for multi-arch expansion)

## Future Expansion

### Multi-Architecture Support
When ready to expand beyond linux/amd64:
1. Update CI workflows to test additional platforms
2. Enable multi-platform Docker builds in release workflows
3. Add platform-specific artifact uploads

### Continuous Deployment (CD)
When infrastructure is ready:
1. Add CD workflow triggered by successful releases
2. Deploy to staging/production environments
3. Health checks and rollback capabilities

## Benefits

1. **Predictable**: Same workflow structure across all projects
2. **Safe**: Multiple validation layers before any publishing
3. **Fast**: Parallel execution and intelligent caching
4. **Maintainable**: Clear separation of concerns
5. **Scalable**: Easy to add new projects following the same pattern

This unified strategy provides a solid foundation for consistent, reliable CI/CD across the entire project ecosystem.
