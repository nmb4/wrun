import "wrun/file" for FileWatcher
import "wrun/print" for Log

var maxEvents = 5
var seen = 0

var watcher = FileWatcher.new(".")
    .recursive(true)
    .pollInterval(0.2)

watcher.onChange(Fn.new { |event|
    seen = seen + 1
    var diff = event["contentDiff"]
    Log.info("File change detected", {
        "kind": event["kind"],
        "path": event["path"],
        "isDirectory": event["isDirectory"],
        "contentChanged": event["contentChanged"],
        "addedLines": diff == null ? 0 : diff["addedCount"],
        "removedLines": diff == null ? 0 : diff["removedCount"],
        "seen": seen
    })

    if (seen >= maxEvents) {
        watcher.stop()
        Log.info("Watcher stopped", {"reason": "max events reached", "maxEvents": maxEvents})
    }
})

Log.info("Watching for changes", {"root": watcher.root, "recursive": true, "maxEvents": maxEvents})
watcher.start().run()
