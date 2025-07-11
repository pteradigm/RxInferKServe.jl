# TASK-0007: Restructure and Formalize Client Libraries

## Overview
Currently, RxInferKServe.jl has a Julia client as part of the main package and a Python client that exists but isn't clearly positioned as official. This task aims to establish both as official client libraries with proper structure, documentation, and packaging.

## Current State
- **Julia Client**: Located in `src/client/client.jl`, part of main package
- **Python Client**: Located in `python/rxinfer_client.py`, unclear status
- **Python Example**: Located in `examples/infinite_stream_demo/client/`, demo-specific
- **README**: Mentions both clients but doesn't clarify official vs example status

## Proposed Solution
Adopt a monorepo approach with multiple official client libraries, following patterns from projects like TensorFlow Serving and MLflow.

## Implementation Plan

### Phase 1: Python Client Formalization
1. **Restructure Python client directory**:
   ```
   clients/
   └── python/
       ├── src/
       │   └── rxinferkserve/
       │       ├── __init__.py
       │       ├── client.py (moved from python/rxinfer_client.py)
       │       └── grpc/
       │           └── (generated protobuf files)
       ├── tests/
       │   ├── __init__.py
       │   ├── test_client.py
       │   └── test_integration.py
       ├── pyproject.toml
       ├── setup.py
       ├── README.md
       └── requirements.txt
   ```

2. **Add proper Python packaging**:
   - Create `pyproject.toml` with modern Python packaging standards
   - Add `setup.py` for backwards compatibility
   - Define package metadata, dependencies, and entry points
   - Add version management (sync with Julia package version)

3. **Implement comprehensive Python client**:
   - Full KServe v2 protocol support (HTTP and gRPC)
   - Async support with `asyncio`
   - Type hints throughout
   - Proper error handling and retries
   - Documentation strings

### Phase 2: Documentation Updates
1. **Update main README.md**:
   - Clear section on "Official Client Libraries"
   - Installation instructions for both clients
   - Quick start examples for each language
   - Link to detailed client documentation

2. **Create client-specific documentation**:
   - `docs/src/clients/julia.md`: Julia client guide
   - `docs/src/clients/python.md`: Python client guide
   - API reference for both clients
   - Migration guide from example to official client

3. **Update examples**:
   - Modify infinite stream demo to use official Python client
   - Add more examples showcasing both clients
   - Create parallel examples in Julia and Python

### Phase 3: CI/CD Integration
1. **Add Python client to CI pipeline**:
   - Python linting (black, flake8, mypy)
   - Python tests (pytest)
   - Python package building
   - Cross-language integration tests

2. **Automated releases**:
   - Publish Python package to PyPI on release
   - Ensure version synchronization
   - Generate client-specific changelogs

### Phase 4: Julia Client Enhancement
1. **Extract client to submodule** (optional):
   - Consider `RxInferKServe.Client` submodule
   - Maintain backwards compatibility
   - Add client-specific tests

2. **Feature parity**:
   - Ensure Julia client has all features of Python client
   - Add async support where applicable
   - Improve error handling

## File Changes

### New Files
- `clients/python/pyproject.toml`
- `clients/python/setup.py`
- `clients/python/README.md`
- `clients/python/src/rxinferkserve/__init__.py`
- `clients/python/src/rxinferkserve/client.py`
- `clients/python/tests/test_client.py`
- `docs/src/clients/julia.md`
- `docs/src/clients/python.md`
- `.github/workflows/python-client.yml`

### Modified Files
- `README.md`: Update client sections
- `CONTRIBUTING.md`: Add Python client development guide
- `.github/workflows/ci.yml`: Add Python tests
- `Makefile`: Add Python client targets
- Move `python/rxinfer_client.py` → `clients/python/src/rxinferkserve/client.py`

### Deleted Files
- `python/rxinfer_client.py` (after moving)

## Benefits
1. **Clear positioning**: Both clients are officially supported
2. **Better discoverability**: Python package on PyPI
3. **Improved maintenance**: CI/CD catches client issues
4. **Ecosystem growth**: Easier for users to adopt
5. **Professional appearance**: Proper packaging and documentation

## Risks and Mitigations
1. **Risk**: Breaking changes for existing Python client users
   - **Mitigation**: Provide migration guide, maintain compatibility layer

2. **Risk**: Increased maintenance burden
   - **Mitigation**: Automated testing, shared protobuf definitions

3. **Risk**: Version synchronization complexity
   - **Mitigation**: Automated version bumping in CI

## Success Criteria
- [ ] Python package installable via `pip install rxinferkserve`
- [ ] Both clients pass all tests in CI
- [ ] Documentation clearly explains both clients
- [ ] Examples work with official clients
- [ ] No breaking changes for existing users

## Timeline Estimate
- Phase 1: 2-3 days
- Phase 2: 1-2 days
- Phase 3: 2-3 days
- Phase 4: 1-2 days

Total: 6-10 days

## Dependencies
- Current PR #7 (Docker restructuring) should be merged first
- Semantic versioning (v0.1.0) is already in place

## Notes
- Consider adding more language clients in the future (JavaScript, Go)
- Could extract clients to separate repos later if needed
- Keep protobuf definitions in server repo as source of truth