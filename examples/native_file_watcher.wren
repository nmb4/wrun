import "wrun/file" for NativeFileWatcher
import "wrun/print" for Log

var maxEvents = 5
var seen = 0

var watcher = NativeFileWatcher.new(".")
    .recursive(true)
    .mode("wait")
    .waitTimeout(0.5)
    .pollInterval(0.1)

watcher.onChange(Fn.new { |event|
    seen = seen + 1
    var diff = event["contentDiff"]
    Log.info("Native file change", {
        "kind": event["kind"],
        "path": event["path"],
        "nativeTimestamp": event["nativeTimestamp"],
        "contentChanged": event["contentChanged"],
        "addedLines": diff == null ? 0 : diff["addedCount"],
        "removedLines": diff == null ? 0 : diff["removedCount"],
        "seen": seen
    })

    if (seen >= maxEvents) {
        watcher.stop()
        Log.info("Native watcher stopped", {"reason": "max events reached", "maxEvents": maxEvents})
    }
})

Log.info("Watching (native)", {"root": watcher.root, "recursive": true, "maxEvents": maxEvents})
watcher.start().run()
