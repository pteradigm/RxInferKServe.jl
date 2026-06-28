# Server configuration management

using Logging

# Global server configuration
const SERVER_CONFIG = Ref{ServerConfig}()

# Initialize server configuration
function init_config(; kwargs...)
    config = ServerConfig(; kwargs...)
    SERVER_CONFIG[] = config

    if config.configure_global_logger
        global_logger(ConsoleLogger(stderr, _logging_level(config.log_level)))
    end

    @info "Server configuration initialized" host=config.host port=config.port workers=config.workers

    return config
end

function _logging_level(log_level::AbstractString)
    normalized = lowercase(log_level)
    if normalized == "debug"
        return Logging.Debug
    elseif normalized == "info"
        return Logging.Info
    elseif normalized == "warn"
        return Logging.Warn
    elseif normalized == "error"
        return Logging.Error
    end

    throw(ArgumentError("unsupported log_level: $log_level"))
end

# Get current configuration
function get_config()
    if !isassigned(SERVER_CONFIG)
        throw(ErrorException("Server configuration not initialized"))
    end
    return SERVER_CONFIG[]
end

# Validate API key
function validate_api_key(key::String)
    config = get_config()

    if !config.enable_auth
        return true
    end

    return key in config.api_keys
end

# CORS headers
function cors_headers()
    config = get_config()

    if !config.enable_cors
        return []
    end

    return [
        "Access-Control-Allow-Origin" => "*",
        "Access-Control-Allow-Methods" => "GET, POST, PUT, DELETE, OPTIONS",
        "Access-Control-Allow-Headers" => "Content-Type, Authorization, X-API-Key",
        "Access-Control-Max-Age" => "86400",
    ]
end
