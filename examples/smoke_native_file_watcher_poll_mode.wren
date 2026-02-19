import "wrun/file" for File, NativeFileWatcher
import "wrun/process" for Process, Shell

var assert = Fn.new { |condition, message|
    if (!condition) {
        System.print("FAIL: %(message)")
        Process.exit(1)
    }
}

var path = ".smoke_native_poll_mode.txt"
if (File.exists(path)) File.delete(path)
File.write(path, "baseline")

var events = []
var watcher = NativeFileWatcher.new(path)
    .recursive(false)
    .mode("poll")
    .pollInterval(0.02)
    .fallbackPolling(true)

watcher.onChange(Fn.new { |event|
    events.add(event)
    watcher.stop()
})

Shell.spawn("sh -c 'sleep 0.2; echo next >> .smoke_native_poll_mode.txt'")
watcher.start().run()

assert.call(events.count > 0, "expected at least one change event in poll mode")

var event = events[0]
assert.call(event["contentChanged"], "expected contentChanged=true")

var diff = event["contentDiff"]
assert.call(diff != null, "expected non-null contentDiff")
assert.call(diff["addedCount"] >= 1, "expected at least one added line")

System.print("PASS: native watcher poll mode smoke test")

if (File.exists(path)) File.delete(path)
