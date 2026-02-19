import "wrun/file" for FileWatcher
import "wrun/print" for Log

// Non-native watcher demo:
// Uses snapshot-based polling (FileWatcher), not OS-native events.
var watchRoot = "."
var maxEvents = 6
var seen = 0

var watcher = FileWatcher.watch(watchRoot, Fn.new { |event|
    seen = seen + 1
    var diff = event["contentDiff"]
    Log.info("Polling watcher event", {
        "kind": event["kind"],
        "path": event["path"],
        "isDirectory": event["isDirectory"],
        "contentChanged": event["contentChanged"],
        "addedLines": diff == null ? 0 : diff["addedCount"],
        "removedLines": diff == null ? 0 : diff["removedCount"],
        "seen": seen
    })

    if (event["prettyDiff"] != null) {
        System.print(event["prettyDiff"])
    }

    if (seen >= maxEvents) {
        watcher.stop()
        Log.info("Watcher stopped", {"reason": "max events reached", "maxEvents": maxEvents})
    }
})
    .pollInterval(0.2)

Log.info("Polling watcher started", {
    "root": watcher.root,
    "recursive": true,
    "maxEvents": maxEvents
})
watcher.run()
