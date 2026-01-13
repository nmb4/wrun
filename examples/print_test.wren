import "wrun/print" for Log
import "wrun/print" for Print

// Configure logging
Log.setTerminalLevel("trace")
Log.setFileLevel("debug")

// Add custom log levels
Log.addLevel("STDOUT", "blue", "info")
Log.addLevel("HTTP", "cyan", "info")
Log.addLevel("DB", "magenta", "debug")

// Simulate application startup
Log.info("Initializing application", {"version": "1.2.0", "env": "development"})
Log.debug("Loading configuration", {"path": "~/.config/myapp.toml"})
Log.trace("Parsing config file")

// Simulate HTTP server
Log.custom("HTTP", "Server listening", {"host": "0.0.0.0", "port": 8080})
Log.custom("HTTP", "GET /api/users", {"method": "GET", "status": 200, "latency": "12ms"})
Log.custom("HTTP", "POST /api/users", {"method": "POST", "status": 201, "latency": "45ms"})

// Simulate database operations
Log.custom("DB", "Connected to database", {"driver": "postgres", "pool_size": 10})
Log.custom("DB", "Query executed", {"table": "users", "rows": 156, "latency": "3ms"})

Log.custom("STDOUT", "Connected to database", {"driver": "postgres", "pool_size": 10})
Log.custom("STDOUT", "Query executed", {"table": "users", "rows": 156, "latency": "3ms"})


// Simulate warnings and errors
Log.warn("High memory usage detected", {"used": "85 percent", "threshold": "80 percent"})
Log.warn("Deprecated API called", {"endpoint": "/v1/legacy", "suggestion": "use /v2/modern"})

Log.error("Failed to connect to cache", {"host": "redis://localhost:6379", "error": "connection refused"})
Log.error("Request timeout", {"url": "/api/slow", "timeout": "30s"})

// Application shutdown
Log.info("Graceful shutdown initiated")
Log.debug("Closing database connections")
Log.info("Application stopped", {"uptime": "2h 15m 32s", "requests_served": 15420})

System.print("\n=== Print Module Tests ===")
Print.eprint("This is an error message to stderr.")
Print.cprint("This is a standard message to stdout.")
Print.cprintColor("This is a colored message to stdout.", "green")
