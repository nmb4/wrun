import "wrun/process" for Shell, Process
import "wrun/file" for File, Dir, Path
import "wrun/env" for Env
import "wrun/args" for Args

System.print("=== wrun demo ===")
System.print("")

// Environment
System.print("OS: %(Env.os())")
System.print("Arch: %(Env.arch())")
System.print("User: %(Env.user())")
System.print("Home: %(Env.home())")
System.print("")

// Arguments
System.print("Args count: %(Args.count())")
var args = Args.all()
for (arg in args) {
    System.print("  - %(arg)")
}
System.print("")

// Run a shell command
System.print("Running 'echo hello world':")
Shell.run("echo hello world")
System.print("stdout: %(Shell.stdout)")
System.print("exit code: %(Shell.exitCode)")
System.print("")

// Run a shell command
System.print("Running 'gum confirm':")
Shell.run("gum confirm")
System.print("stdout: %(Shell.stdout)")
System.print("exit code: %(Shell.exitCode)")
System.print("")

// File operations
var testFile = "/tmp/wrun_test.txt"
System.print("Writing to %(testFile)...")
File.write(testFile, "Hello from wrun!\nThis is a test file.")
System.print("File exists: %(File.exists(testFile))")
System.print("File size: %(File.size(testFile)) bytes")
System.print("Content:")
System.print(File.read(testFile))

// Cleanup
File.delete(testFile)
System.print("Cleaned up test file.")
System.print("")

// Current directory
System.print("Current directory: %(Process.cwd())")

// Path utilities
System.print("Path.join('foo', 'bar'): %(Path.join("foo", "bar"))")
System.print("Path.basename('/usr/bin/ls'): %(Path.basename("/usr/bin/ls"))")
System.print("Path.dirname('/usr/bin/ls'): %(Path.dirname("/usr/bin/ls"))")
System.print("Path.extension('test.txt'): %(Path.extension("test.txt"))")

System.print("")
System.print("=== Done! ===")
