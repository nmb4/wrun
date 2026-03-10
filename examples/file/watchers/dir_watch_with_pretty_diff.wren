import "wrun/file" for Watcher, File
import "wrun/args" for Args
import "wrun/print" for Log
import "wrun/str" for Str

// Watch a directory indefinitely and print file events with pretty diffs
// Usage: wrun dir_watch_with_pretty_diff.wren [directory]

var watchRoot = "."

// Accept optional directory argument
if (Args.count() > 0) {
    watchRoot = Args.get(0)
}

// Verify directory exists
if (!File.isDirectory(watchRoot)) {
    Log.error("Not a valid directory", {"path": watchRoot})
    System.exit(1)
}

var eventCount = 0

// Color codes for terminal output
var BOLD = "\u001b[1m"
var RESET = "\u001b[0m"
var GREEN = "\u001b[32m"
var YELLOW = "\u001b[33m"
var RED = "\u001b[31m"
var CYAN = "\u001b[36m"
var GRAY = "\u001b[90m"

// Create watcher with handler
var watcher = Watcher.watchDir(watchRoot, Fn.new { |event|
    eventCount = eventCount + 1
    
    var kind = event["kind"]
    var path = event["path"]
    var isDir = event["isDirectory"]
    var contentChanged = event["contentChanged"]
    var prettyDiff = event["prettyDiff"]
    
    // Determine kind color
    var kindColor = YELLOW
    if (kind == "created") {
        kindColor = GREEN
    } else if (kind == "deleted") {
        kindColor = RED
    }
    
    // Print event header
    System.print("")
    System.print("%(CYAN)%(BOLD)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%(RESET)")
    
    var typeLabel = isDir ? "DIR" : "FILE"
    var kindUpper = Str.toUpper(kind)
    System.print("%(kindColor)%(BOLD)%(kindUpper)%(RESET) [%(typeLabel)] %(path)")
    
    // Print content diff if available
    if (contentChanged && prettyDiff != null) {
        System.print("")
        System.print("%(BOLD)Content Diff:%(RESET)")
        System.print(prettyDiff)
    } else if (contentChanged && !isDir) {
        System.print("%(GRAY)(Content changed, pretty diff unavailable)%(RESET)")
    }
    
    // Print metadata for native events
    if (event["native"]) {
        var ts = event["nativeTimestamp"]
        System.print("%(GRAY)native=true | timestamp=%(ts)%(RESET)")
    }
})

Log.info("Directory watcher started", {
    "root": watcher.root,
    "mode": "indefinite (press Ctrl+C to stop)",
    "recursive": true,
    "prettyDiff": "enabled"
})

System.print("%(CYAN)📋 Watching directory: %(watcher.root)%(RESET)")
System.print("%(CYAN)⏳ Listening for changes... (Press Ctrl+C to stop)%(RESET)")
System.print("")

// Run watcher indefinitely
watcher.run()
