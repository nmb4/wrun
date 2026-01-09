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
```

### wrun/file

File system operations.

```wren
import "wrun/file" for File, Dir, Path

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
