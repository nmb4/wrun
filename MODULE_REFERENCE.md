# Wren Runtime (wrun) Module Reference

A comprehensive reference for all custom modules provided by the wrun runtime.

---

## Table of Contents

1. [wrun/print](#wrunprint) - Printing, logging, and colored output
2. [wrun/str](#wrunstr) - String utilities and manipulation
3. [wrun/file](#wrunfile) - File system operations
4. [wrun/env](#wrunenv) - Environment variables and system info
5. [wrun/args](#wrunargs) - Command-line arguments
6. [wrun/process](#wrunprocess) - Process control and shell commands

---

## wrun/print

Printing, logging, and colored output utilities.

### Print Class

Simple printing utilities for stdout/stderr.

```wren
import "wrun/print" for Print
```

| Method | Description |
|--------|-------------|
| `Print.new()` | Constructor (required for instantiation, though static methods exist) |
| `Print.eprint(msg)` | Print message to stderr without newline |
| `Print.cprint(msg)` | Print message to stdout without newline |
| `Print.cprint(msg, color)` | Print colored message to stdout |

**Color Values** (passed as string to `cprint`):
- `"black"`, `"red"`, `"green"`, `"yellow"`, `"blue"`, `"magenta"`, `"cyan"`, `"white"`
- Bright variants: `"brightBlack"`, `"brightRed"`, etc.
- Reset: `"reset"`

---

### LogInternal Class

Low-level logging with structured key-value support. Used internally by the `Log` wrapper.

```wren
import "wrun/print" for LogInternal
```

| Method | Description |
|--------|-------------|
| `LogInternal.new()` | Constructor |
| `LogInternal.trace(msg)` | Log at TRACE level (lowest, most verbose) |
| `LogInternal.traceKv(msg, kv)` | Log trace with key-value pairs |
| `LogInternal.debug(msg)` | Log at DEBUG level (detailed debug info) |
| `LogInternal.debugKv(msg, kv)` | Log debug with key-value pairs |
| `LogInternal.info(msg)` | Log at INFO level (general information) |
| `LogInternal.infoKv(msg, kv)` | Log info with key-value pairs |
| `LogInternal.warn(msg)` | Log at WARN level (warnings) |
| `LogInternal.warnKv(msg, kv)` | Log warning with key-value pairs |
| `LogInternal.error(msg)` | Log at ERROR level (errors) |
| `LogInternal.errorKv(msg, kv)` | Log error with key-value pairs |
| `LogInternal.custom(level, msg)` | Log with custom level name |
| `LogInternal.customKv(level, msg, kv)` | Log custom level with key-value pairs |

#### Configuration Methods

| Method | Description |
|--------|-------------|
| `LogInternal.setFile(path)` | Set a file path to write logs to (in addition to terminal) |
| `LogInternal.setTerminalLevel(level)` | Set minimum level to display in terminal |
| `LogInternal.setFileLevel(level)` | Set minimum level to write to log file |
| `LogInternal.addLevel(name, color, baseLevel)` | Add a custom log level |

**Log Levels** (in order of severity):
```
trace (0) < debug (1) < info (2) < warn (3) < error (4)
```

---

### Log Class (Recommended)

Wrapper around `LogInternal` that handles Map serialization for structured logging.

```wren
import "wrun/print" for Log
```

| Method | Description |
|--------|-------------|
| `Log.trace(msg)` | Log trace message |
| `Log.trace(msg, kv)` | Log trace with Map of key-value pairs |
| `Log.debug(msg)` | Log debug message |
| `Log.debug(msg, kv)` | Log debug with Map of key-value pairs |
| `Log.info(msg)` | Log info message |
| `Log.info(msg, kv)` | Log info with Map of key-value pairs |
| `Log.warn(msg)` | Log warning message |
| `Log.warn(msg, kv)` | Log warning with Map of key-value pairs |
| `Log.error(msg)` | Log error message |
| `Log.error(msg, kv)` | Log error with Map of key-value pairs |
| `Log.custom(level, msg)` | Log with custom level string |
| `Log.custom(level, msg, kv)` | Log custom level with key-value Map |

**Key-Value Format**: Pass a Wren `Map` which gets serialized to `key=value\0key=value` format.

**Configuration Methods** (chainable):
| Method | Description |
|--------|-------------|
| `Log.setFile(path)` | Set log file output path |
| `Log.setTerminalLevel(level)` | Set terminal log level filter |
| `Log.setFileLevel(level)` | Set file log level filter |
| `Log.addLevel(name)` | Add custom log level (default color/level) |
| `Log.addLevel(name, color)` | Add custom level with color |
| `Log.addLevel(name, color, baseLevel)` | Add custom level with color and base severity level |

**Log Level Examples**:
```wren
Log.info("Application started")
Log.warn("Low memory", {"percent": 15})
Log.error("Connection failed", {"host": "localhost", "port": 8080})

// Configure logging
Log.setFile("app.log")
Log.setTerminalLevel("debug")
```

---

## wrun/str

Comprehensive string manipulation utilities.

```wren
import "wrun/str" for Str
```

### Validation Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `Str.isEmpty(s)` | `Bool` | Returns `true` if string is empty (`""`) |
| `Str.isBlank(s)` | `Bool` | Returns `true` if string contains only whitespace |
| `Str.isNumeric(s)` | `Bool` | Returns `true` if string contains only digits |
| `Str.isAlpha(s)` | `Bool` | Returns `true` if string contains only letters (A-Z, a-z) |
| `Str.isAlphaNumeric(s)` | `Bool` | Returns `true` if string contains only letters and digits |
| `Str.isUpper(s)` | `Bool` | Returns `true` if all characters are uppercase |
| `Str.isLower(s)` | `Bool` | Returns `true` if all characters are lowercase |

### Transformation Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `Str.trim(s)` | `String` | Removes leading and trailing whitespace |
| `Str.trimStart(s)` | `String` | Removes leading whitespace only |
| `Str.trimEnd(s)` | `String` | Removes trailing whitespace only |
| `Str.toUpper(s)` | `String` | Converts all characters to uppercase |
| `Str.toLower(s)` | `String` | Converts all characters to lowercase |
| `Str.capitalize(s)` | `String` | Capitalizes first letter, lowercases rest |
| `Str.reverse(s)` | `String` | Reverses the string |
| `Str.repeat(s, count)` | `String` | Repeats string `count` times |
| `Str.padStart(s, length, pad)` | `String` | Pads start of string to reach `length` using `pad` char(s) |
| `Str.padEnd(s, length, pad)` | `String` | Pads end of string to reach `length` using `pad` char(s) |
| `Str.camelCase(s)` | `String` | Converts to `camelCase` (e.g., `"hello_world"` -> `"helloWorld"`) |
| `Str.snakeCase(s)` | `String` | Converts to `snake_case` (e.g., `"helloWorld"` -> `"hello_world"`) |
| `Str.kebabCase(s)` | `String` | Converts to `kebab-case` (e.g., `"helloWorld"` -> `"hello-world"`) |
| `Str.truncate(s, length)` | `String` | Truncates string to `length` with `"..."` ellipsis |
| `Str.truncateWith(s, length, ellipsis)` | `String` | Truncates with custom ellipsis string |
| `Str.replace(s, old, new)` | `String` | Replaces first occurrence of `old` with `new` |
| `Str.replaceAll(s, old, new)` | `String` | Replaces all occurrences of `old` with `new` |

### Search Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `Str.contains(s, sub)` | `Bool` | Returns `true` if string contains substring |
| `Str.startsWith(s, prefix)` | `Bool` | Returns `true` if string starts with prefix |
| `Str.endsWith(s, suffix)` | `Bool` | Returns `true` if string ends with suffix |
| `Str.indexOf(s, sub)` | `Num` | Returns index of first occurrence, `-1` if not found |
| `Str.lastIndexOf(s, sub)` | `Num` | Returns index of last occurrence, `-1` if not found |
| `Str.count(s, sub)` | `Num` | Returns number of occurrences of substring |

### Split/Join Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `Str.split(s, sep)` | `List` | Splits string by separator, returns list |
| `Str.splitLimit(s, sep, limit)` | `List` | Splits with maximum number of parts |
| `Str.lines(s)` | `List` | Splits into lines (handles `\n`, `\r\n`) |
| `Str.chars(s)` | `List` | Splits into individual characters |
| `Str.words(s)` | `List` | Splits on whitespace into words |

### Slice Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `Str.slice(s, start)` | `String` | Returns substring from `start` to end |
| `Str.sliceRange(s, start, end)` | `String` | Returns substring from `start` to `end` (exclusive) |
| `Str.at(s, index)` | `String` | Returns character at index (single-char string) |

### Length Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `Str.length(s)` | `Num` | Returns character count (Unicode-aware) |
| `Str.byteLength(s)` | `Num` | Returns byte count in UTF-8 encoding |

**Examples**:
```wren
System.print(Str.capitalize("hello WORLD"))  // "Hello world"
System.print(Str.camelCase("XML_PARSER"))    // "xmlParser"
System.print(Str.truncateWith("Hello world", 5, "..."))  // "He..."
System.print(Str.splitLimit("a,b,c", ",", 2)) // ["a", "b,c"]
```

---

## wrun/file

File system operations and path utilities.

```wren
import "wrun/file" for File, Dir, PathUtil, Path
```

### File Class

| Method | Returns | Description |
|--------|---------|-------------|
| `File.new()` | `File` | Constructor |
| `File.read(path)` | `String` | Reads entire file contents as string |
| `File.readBytes(path)` | `List` | Reads file as list of bytes |
| `File.write(path, content)` | `Bool` | Writes string to file, returns `true` on success |
| `File.writeBytes(path, bytes)` | `Bool` | Writes bytes to file, returns `true` on success |
| `File.append(path, content)` | `Bool` | Appends string to file, returns `true` on success |
| `File.exists(path)` | `Bool` | Returns `true` if path exists |
| `File.isFile(path)` | `Bool` | Returns `true` if path is a regular file |
| `File.isDirectory(path)` | `Bool` | Returns `true` if path is a directory |
| `File.delete(path)` | `Bool` | Deletes file, returns `true` on success |
| `File.copy(from, to)` | `Bool` | Copies file from `from` to `to`, returns `true` on success |
| `File.rename(from, to)` | `Bool` | Renames/moves file, returns `true` on success |
| `File.mkdir(path)` | `Bool` | Creates directory (and parents), returns `true` on success |
| `File.size(path)` | `Num` | Returns file size in bytes, `-1` if not found |

### Dir Class

| Method | Returns | Description |
|--------|---------|-------------|
| `Dir.new()` | `Dir` | Constructor |
| `Dir.list(path)` | `List` | Returns list of entries in directory |
| `Dir.create(path)` | `Bool` | Creates directory, returns `true` on success |
| `Dir.remove(path)` | `Bool` | Removes empty directory, returns `true` on success |
| `Dir.exists(path)` | `Bool` | Returns `true` if directory exists |

### PathUtil Class

| Method | Returns | Description |
|--------|---------|-------------|
| `PathUtil.new()` | `PathUtil` | Constructor |
| `PathUtil.join(a, b)` | `String` | Joins path components with separator |
| `PathUtil.dirname(path)` | `String` | Returns parent directory path |
| `PathUtil.basename(path)` | `String` | Returns file/directory name |
| `PathUtil.extension(path)` | `String` | Returns file extension (including `.`) |
| `PathUtil.absolute(path)` | `String` | Returns absolute path |
| `PathUtil.isAbsolute(path)` | `Bool` | Returns `true` if path is absolute |

### Path Class (Convenience Wrapper)

Static methods wrapping `PathUtil` for convenience.

| Method | Returns | Description |
|--------|---------|-------------|
| `Path.join(a, b)` | `String` | Joins path components |
| `Path.dirname(path)` | `String` | Returns directory name |
| `Path.basename(path)` | `String` | Returns base name |
| `Path.extension(path)` | `String` | Returns file extension |
| `Path.absolute(path)` | `String` | Returns absolute path |
| `Path.isAbsolute(path)` | `Bool` | Checks if path is absolute |

**Examples**:
```wren
var content = File.read("config.json")
File.write("backup.json", content)

var entries = Dir.list(".")
for (entry in entries) {
    System.print(entry)
}

var path = Path.join("src", "main.wren")
System.print(Path.extension(path))  // ".wren"
```

---

## wrun/env

Environment variables and system information.

```wren
import "wrun/env" for Env
```

| Method | Returns | Description |
|--------|---------|-------------|
| `Env.new()` | `Env` | Constructor |
| `Env.get(key)` | `String` | Returns value of environment variable, `null` if not set |
| `Env.set(key, value)` | `Bool` | Sets environment variable, returns `true` on success |
| `Env.remove(key)` | `Bool` | Removes environment variable, returns `true` on success |
| `Env.has(key)` | `Bool` | Returns `true` if variable is set |
| `Env.all()` | `List` | Returns all variables as `["KEY=value", ...]` list |
| `Env.keys()` | `List` | Returns list of all variable names |
| `Env.home()` | `String` | Returns home directory path |
| `Env.user()` | `String` | Returns current username |
| `Env.os()` | `String` | Returns OS name: `"macos"`, `"linux"`, or `"windows"` |
| `Env.arch()` | `String` | Returns CPU architecture: `"aarch64"`, `"x86_64"`, etc. |

**Examples**:
```wren
var apiKey = Env.get("API_KEY")
if (apiKey == null) {
    System.print("API_KEY not set")
}

Env.set("MY_VAR", "hello")
Env.home()  // "/Users/username" or "/home/username"

System.print("Running on %(Env.os()) for %(Env.arch())")
```

---

## wrun/args

Command-line arguments access.

```wren
import "wrun/args" for Args
```

| Method | Returns | Description |
|--------|---------|-------------|
| `Args.new()` | `Args` | Constructor |
| `Args.all()` | `List` | Returns all arguments (excludes script path) |
| `Args.count()` | `Num` | Returns number of arguments |
| `Args.get(index)` | `String` | Returns argument at index |
| `Args.first()` | `String` | Returns first argument |
| `Args.last()` | `String` | Returns last argument |
| `Args.has(index)` | `Bool` | Returns `true` if index exists |
| `Args.slice(start, end)` | `List` | Returns arguments in range `[start, end)` |

**Argument Order**: When running `wrun script.wren --flag value`:
- `Args.all()` returns `["--flag", "value"]` (script path excluded)
- `Args.get(0)` returns `"--flag"`

**Examples**:
```wren
var args = Args.all()
System.print("Received %(Args.count()) arguments")

if (Args.has(1)) {
    System.print("First arg: %(Args.first())")
    System.print("Last arg: %(Args.last())")
}
```

---

## wrun/process

Process control and shell command execution.

```wren
import "wrun/process" for Process, Shell
```

### Process Class

Process-level operations and current working directory.

| Method | Returns | Description |
|--------|---------|-------------|
| `Process.new()` | `Process` | Constructor |
| `Process.cwd()` | `String` | Returns current working directory |
| `Process.chdir(path)` | `Bool` | Changes directory, returns `true` on success |
| `Process.exit(code)` | (never returns) | Exits process with code (0-255) |

### Shell Class

Shell command execution with output capture.

| Method/Property | Returns | Description |
|-----------------|---------|-------------|
| `Shell.new()` | `Shell` | Constructor |
| `Shell.run(command)` | `Bool` | Runs command, returns `true` on success, captures output |
| `Shell.stdout` | `String` | Property: captured stdout from last `run()` |
| `Shell.stderr` | `String` | Property: captured stderr from last `run()` |
| `Shell.exitCode` | `Num` | Property: exit code from last `run()` |
| `Shell.success` | `Bool` | Property: `true` if exit code is 0 |
| `Shell.exec(command)` | `Num` | Executes command, returns exit code immediately |
| `Shell.interactive(command)` | `Bool` | Runs command interactively (terminal control), returns `true` |
| `Shell.spawn(command)` | `Bool` | Spawns background process, returns `true` |

**Examples**:
```wren
// Change directory
Process.chdir("/tmp")

// Run command and check results
Shell.run("ls -la")
System.print("Output: %(Shell.stdout)")
System.print("Errors: %(Shell.stderr)")
System.print("Exit code: %(Shell.exitCode)")
System.print("Success: %(Shell.success)")

// Execute and get exit code immediately
var code = Shell.exec("echo hello")
if (code == 0) {
    System.print("Command succeeded")
}

// Spawn background process
Shell.spawn("long-running-task --daemon")
```

---

## Quick Import Reference

```wren
import "wrun/print" for Print, Log
import "wrun/str" for Str
import "wrun/file" for File, Dir, Path
import "wrun/env" for Env
import "wrun/args" for Args
import "wrun/process" for Process, Shell
```

---

## Complete Usage Example

```wren
import "wrun/print" for Log, Print
import "wrun/str" for Str
import "wrun/file" for File, Dir, Path
import "wrun/env" for Env
import "wrun/args" for Args
import "wrun/process" for Shell, Process

// Logging with structured data
Log.info("Application starting", {"version": "1.0.0", "env": Env.os()})

// String manipulation
var input = "  hello_world  "
System.print(Str.trim(input))           // "hello_world"
System.print(Str.camelCase(input))      // "HelloWorld"

// File operations
var configPath = Path.join("config", "app.json")
if (File.exists(configPath)) {
    var content = File.read(configPath)
    Log.debug("Config loaded", {"size": Str.byteLength(content)})
}

// Environment
Env.set("APP_MODE", "production")
Log.info("Environment configured", {"mode": Env.get("APP_MODE")})

// Arguments
if (Args.count() > 0) {
    Log.info("Args received", {"count": Args.count()})
}

// Shell commands
Shell.run("echo 'Build complete!'")
if (!Shell.success) {
    Log.error("Build failed", {"error": Shell.stderr})
}

// Process control
Log.info("Working directory: %(Process.cwd())")
```
