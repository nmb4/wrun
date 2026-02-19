# wrun

A CLI runner for Wren scripts with system integration, powered by [ruwren](https://github.com/Jengamon/ruwren).

## Installation

```bash
cargo install --path .
```

## Usage

```bash
wrun script.wren [args...]
```

## Built-in Modules

### wrun/process

Execute shell commands and manage processes.

```wren
import "wrun/process" for Shell, Process

// Run a command and capture output
Shell.run("ls -la")
System.print(Shell.stdout)
System.print("Exit code: %(Shell.exitCode)")

// Execute a command (returns exit code)
var code = Shell.exec("echo hello")

// Spawn a background process
Shell.spawn("sleep 10")

// Get current working directory
System.print(Process.cwd())

// Change directory
Process.chdir("/tmp")

// Exit with code
Process.exit(0)

// Sleep for 250ms
Process.sleep(0.25)
```

### wrun/file

File system operations.

```wren
import "wrun/file" for File, Dir, Path, FileWatcher, NativeFileWatcher, Diff

// Read/write files
File.write("test.txt", "Hello World")
var content = File.read("test.txt")
File.append("test.txt", "\nMore content")

// Read/write binary
var bytes = File.readBytes("image.png")
File.writeBytes("copy.png", bytes)

// File info
File.exists("test.txt")   // true/false
File.isFile("test.txt")   // true/false
File.isDirectory("/tmp")  // true/false
File.size("test.txt")     // size in bytes
File.modified("test.txt") // last-modified Unix timestamp (seconds)

// File operations
File.copy("a.txt", "b.txt")
File.rename("old.txt", "new.txt")
File.delete("test.txt")
File.mkdir("new/nested/dir")

// Directory operations
Dir.list("/tmp")          // returns list of entries
Dir.create("new/dir")
Dir.remove("old/dir")
Dir.exists("/tmp")

// Path utilities
Path.join("foo", "bar")      // "foo/bar"
Path.dirname("/usr/bin/ls")  // "/usr/bin"
Path.basename("/usr/bin/ls") // "ls"
Path.extension("test.txt")   // "txt"
Path.absolute("./file.txt")  // full path
Path.isAbsolute("/tmp")      // true

// Pretty diff + patch helpers (similar + diffy)
var before = "a\nb\nc\n"
var after = "a\nB\nc\n"
System.print(Diff.pretty("demo.txt", before, after, "line"))  // line/word/char
System.print(Diff.pretty("demo.txt", before, after, "line", "patience")) // algorithm: myers/patience/lcs
var patch = Diff.patch("demo.txt", before, after)
var applyResult = Diff.applyPatchResult(before, patch) // ["ok", "..."] or ["error", "..."]

// Watch changes (handler called through fibers with context map)
var watcher = FileWatcher
    .watch(".", Fn.new { |event|
        System.print("%(event[\"kind\"]) %(event[\"path\"])")
        if (event["prettyDiff"] != null) {
            System.print(event["prettyDiff"]) // ANSI colored output
        }
        if (event["contentChanged"]) {
            var diff = event["contentDiff"]
            System.print("  +%(diff[\"addedCount\"]) -%(diff[\"removedCount\"]) at line %(diff[\"startLine\"])")
        }
    })
    .recursive(true)
    .diffGranularity("line")
    .diffAlgorithm("myers")
    .includePrettyDiff(true)
    .includePatch(true)
    .pollInterval(0.2)

watcher.run()

// Native OS-backed watcher (via notify backend)
// Falls back to metadata polling until native events are observed.
var nativeWatcher = NativeFileWatcher
    .watch(".", Fn.new { |event|
        System.print("native %(event[\"kind\"]) %(event[\"path\"])")
        if (event["prettyDiff"] != null) {
            System.print(event["prettyDiff"]) // ANSI colored output
        }
        if (event["contentChanged"]) {
            var diff = event["contentDiff"]
            System.print("  +%(diff[\"addedCount\"]) -%(diff[\"removedCount\"]) at line %(diff[\"startLine\"])")
        }
    })
    .recursive(true)
    .diffGranularity("line")
    .diffAlgorithm("myers")
    .includePrettyDiff(true)
    .includePatch(true)
    .mode("wait")        // "wait" (blocking) or "poll"
    .waitTimeout(0.5)    // blocking wait timeout in seconds
    .fallbackPolling(true)
    .pollInterval(0.1)

nativeWatcher.run()
```

### wrun/env

Environment variables and system info.

```wren
import "wrun/env" for Env

// Get/set environment variables
var path = Env.get("PATH")
Env.set("MY_VAR", "value")
Env.remove("MY_VAR")
Env.has("HOME")  // true/false

// List all variables
var all = Env.all()   // ["KEY=value", ...]
var keys = Env.keys() // ["KEY", ...]

// System info
Env.os()    // "macos", "linux", "windows"
Env.arch()  // "aarch64", "x86_64", etc.
Env.home()  // home directory
Env.user()  // current username
```

### wrun/args

Access command-line arguments.

```wren
import "wrun/args" for Args

// Get all arguments (excluding script path)
var args = Args.all()

// Access by index
var first = Args.get(0)
var count = Args.count()

// Convenience methods
Args.first()        // first argument
Args.last()         // last argument
Args.has(2)         // check if index exists
Args.slice(1, 3)    // get range of args
```

## Watcher Example Scripts

All of these run from this project directory and leave no artifacts behind.

```bash
# Native watcher demos
cargo run --quiet -- examples/native_file_watcher.wren
cargo run --quiet -- examples/native_file_watcher_poll_mode.wren

# Content diff demos
cargo run --quiet -- examples/file_watcher_diff_simple.wren
cargo run --quiet -- examples/file_watcher_diff_detailed.wren

# Smoke tests
cargo run --quiet -- examples/smoke_native_file_watcher_poll_mode.wren
cargo run --quiet -- examples/smoke_native_file_watcher_wait_mode.wren
cargo run --quiet -- examples/smoke_file_watcher_content_diff.wren
```

## Example Script

```wren
#!/usr/bin/env wrun
import "wrun/process" for Shell
import "wrun/args" for Args
import "wrun/env" for Env

System.print("Hello, %(Env.user())!")
System.print("Running on %(Env.os()) (%(Env.arch()))")

if (Args.count() > 0) {
    System.print("Args: %(Args.all())")
}

Shell.run("date")
System.print("Current time: %(Shell.stdout.trim())")
```

## License

MIT
