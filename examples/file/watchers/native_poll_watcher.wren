import "wrun/file" for NativeFileWatcher
import "wrun/print" for Log

var watchRoot = "."
var maxEvents = 8
var seen = 0

var watcher = null
watcher = NativeFileWatcher.watchDir(watchRoot, Fn.new { |event|
    seen = seen + 1
    var diff = event["contentDiff"]
    Log.info("Native watcher event (poll mode)", {
        "kind": event["kind"],
        "path": event["path"],
        "native": event["native"],
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
        Log.info("Native watcher stopped", {
            "mode": watcher.runMode,
            "reason": "max events reached",
            "maxEvents": maxEvents
        })
    }
})
    .mode("poll")
    .pollInterval(0.1)

Log.info("Native watcher started (poll mode)", {
    "root": watcher.root,
    "mode": watcher.runMode,
    "recursive": true,
    "maxEvents": maxEvents
})
watcher.run()
