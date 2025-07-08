# Server API

## Starting the Server

### Basic Usage

```julia
start_server(; kwargs...)
```

Start the RxInferKServe server with specified configuration.

**Keyword Arguments:**
- `host::String = "127.0.0.1"`: Host address to bind
- `port::Int = 8080`: HTTP port
- `grpc_port::Int = 8081`: gRPC port
- `enable_grpc::Bool = true`: Enable gRPC server
- `workers::Int = 1`: Number of worker processes
- `enable_auth::Bool = false`: Enable API key authentication
- `api_keys::Vector{String} = []`: Valid API keys
- `enable_cors::Bool = true`: Enable CORS headers
- `log_level::String = "info"`: Logging level

**Example:**
```julia
start_server(
    host="0.0.0.0",
    port=8080,
    enable_auth=true,
    api_keys=["secret-key-123"],
    log_level="debug"
)
```

## Authentication

When authentication is enabled, include the API key in requests:

```julia
# Julia client
client = RxInferClient("http://localhost:8080", api_key="secret-key-123")

# HTTP header
Authorization: Bearer secret-key-123
```

## CORS Configuration

CORS is enabled by default with permissive settings. For production:

```julia
# Customize CORS in server middleware
function setup_cors(req)
    headers = [
        "Access-Control-Allow-Origin" => "https://myapp.com",
        "Access-Control-Allow-Methods" => "GET, POST, DELETE",
        "Access-Control-Allow-Headers" => "Content-Type, Authorization"
    ]
    return headers
end
```

## Health Checks

The server provides health check endpoints:

- `/v2/health/live` - Liveness probe (is server running?)
- `/v2/health/ready` - Readiness probe (can server handle requests?)

```bash
# Check server health
curl http://localhost:8080/v2/health/ready
```

## Metrics and Monitoring

The server logs structured JSON for monitoring:

```json
{
    "timestamp": "2024-01-15T10:30:45Z",
    "level": "info",
    "method": "POST",
    "path": "/v2/models/coin_flip/infer",
    "status": 200,
    "duration_ms": 45,
    "model": "coin_flip"
}
```

## Configuration File

Create a `config.toml` for server configuration:

```toml
[server]
host = "0.0.0.0"
port = 8080
grpc_port = 8081
workers = 4

[auth]
enabled = true
api_keys = ["key1", "key2"]

[logging]
level = "info"
format = "json"
```

Load configuration:
```julia
config = load_config("config.toml")
start_server(; config...)
```

## API Reference

```@docs
RxInferKServe.start_server
RxInferKServe.stop_server
RxInferKServe.ServerConfig
```