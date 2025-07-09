# Contributing to RxInferKServe.jl

Thank you for your interest in contributing to RxInferKServe.jl! This document provides guidelines and instructions for contributing to the project.

## Development Setup

### Prerequisites

- Julia 1.10 or higher
- Git
- Docker (optional, for container testing)

### Getting Started

1. Fork and clone the repository:
   ```bash
   git clone https://github.com/your-username/RxInferKServe.jl.git
   cd RxInferKServe.jl
   ```

2. Install dependencies:
   ```bash
   julia --project=. -e 'using Pkg; Pkg.instantiate()'
   ```

3. Run tests to ensure everything works:
   ```bash
   julia --project=. -e 'using Pkg; Pkg.test()'
   ```

## Code Style

We use JuliaFormatter to maintain consistent code style across the project.

### Setting Up Pre-commit Hook (Recommended)

To automatically format your code before each commit:

```bash
# Configure git to use our hooks directory
git config core.hooksPath .githooks

# Verify the configuration
git config --get core.hooksPath
# Should output: .githooks
```

The pre-commit hook will:
- Automatically run JuliaFormatter on staged Julia files
- Re-stage formatted files if changes were made
- Prevent commits with improperly formatted code

### Manual Formatting

If you prefer to format manually:

```bash
# Install JuliaFormatter (if not already installed)
julia -e 'using Pkg; Pkg.add("JuliaFormatter")'

# Format all files
julia -e 'using JuliaFormatter; format(".")'

# Format specific file
julia -e 'using JuliaFormatter; format("src/server.jl")'
```

### Disabling Pre-commit Hook Temporarily

If you need to bypass the hook for a specific commit:

```bash
git commit --no-verify -m "your message"
```

## Commit Guidelines

We follow [Conventional Commits](https://www.conventionalcommits.org/) for clear and automated versioning:

- `feat:` - New features (triggers minor version bump)
- `fix:` - Bug fixes (triggers patch version bump)
- `docs:` - Documentation changes
- `style:` - Code style changes (formatting, etc.)
- `refactor:` - Code refactoring without behavior change
- `perf:` - Performance improvements
- `test:` - Test additions or modifications
- `chore:` - Maintenance tasks
- `ci:` - CI/CD changes

Breaking changes should include `BREAKING CHANGE:` in the commit body or footer.

### Examples

```bash
# Feature
git commit -m "feat: Add support for custom model serialization"

# Bug fix
git commit -m "fix: Correct inference response format for arrays"

# Breaking change
git commit -m "feat!: Update API to KServe v2 protocol

BREAKING CHANGE: API endpoints now use /v2 prefix"
```

## Pull Request Process

1. **Create a feature branch**:
   ```bash
   git checkout -b feat/your-feature-name
   ```

2. **Make your changes** following the code style guidelines

3. **Write/update tests** for your changes

4. **Update documentation** if needed

5. **Run tests locally**:
   ```bash
   make test
   ```

6. **Push to your fork** and create a pull request

7. **Ensure CI passes** - All checks must be green

8. **Address review feedback** if any

## Testing

### Running Tests

```bash
# Run all tests
make test

# Run specific test file
julia --project=. test/test_server.jl

# Run with coverage
julia --project=. -e 'using Pkg; Pkg.test(coverage=true)'
```

### Writing Tests

- Place tests in `test/` directory
- Use descriptive test names
- Test both success and failure cases
- Include edge cases

## Documentation

### Building Documentation Locally

```bash
julia --project=docs -e 'using Pkg; Pkg.instantiate()'
julia --project=docs docs/make.jl
```

Documentation will be generated in `docs/build/`.

### Documentation Guidelines

- Update docstrings for new/modified functions
- Include examples in docstrings
- Update relevant documentation pages
- Keep README.md in sync with major changes

## Development Tools

### Makefile Targets

```bash
make help       # Show all available targets
make deps       # Install dependencies
make build      # Build the project
make test       # Run tests
make sysimage   # Build system image
make format     # Format code with JuliaFormatter
```

### Docker Development

```bash
# Build Docker image
docker build -f docker/Dockerfile -t rxinferkserve:dev .

# Run container
docker run -p 8080:8080 rxinferkserve:dev

# Use docker-compose
cd docker && docker-compose up
```

## Questions or Issues?

- Open an issue for bugs or feature requests
- Join discussions for questions or ideas
- Check existing issues before creating new ones

Thank you for contributing to RxInferKServe.jl!