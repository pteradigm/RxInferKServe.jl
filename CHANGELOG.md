# Changelog

## [Unreleased]

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

Initial implementation of RxInferKServe with v1 API.