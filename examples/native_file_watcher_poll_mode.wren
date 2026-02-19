import "wrun/file" for NativeFileWatcher
import "wrun/print" for Log

var maxEvents = 8
var seen = 0

var watcher = NativeFileWatcher.new(".")
    .recursive(true)
    .mode("poll")
    .diffGranularity("line")
    .diffAlgorithm("myers")
    .includePatch(true)
    .includePrettyDiff(true)
    .pollInterval(0.1)
    .fallbackPolling(true)

watcher.onChange(Fn.new { |event|
    seen = seen + 1
    var diff = event["contentDiff"]
    Log.info("Native file change (poll mode)", {
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

Log.info("Watching (native poll mode)", {
    "root": watcher.root,
    "mode": watcher.runMode,
    "recursive": true,
    "maxEvents": maxEvents
})

watcher.start().run()
