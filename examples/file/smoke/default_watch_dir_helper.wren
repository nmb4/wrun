import "wrun/file" for File, Path, Watcher
import "wrun/process" for Process, Shell

var assert = Fn.new { |condition, message|
    if (!condition) {
        System.print("FAIL: %(message)")
        Process.exit(1)
    }
}

var dir = ".smoke_default_watch_dir_helper"
var file = dir + "/state.txt"
var expectedPath = Path.absolute(file)

if (File.exists(dir)) File.delete(dir)
File.mkdir(dir)
File.write(file, "alpha\n")

var events = []
var watcher = null
watcher = Watcher.watchDir(dir, Fn.new { |event|
    events.add(event)
    if (event["path"] == expectedPath && event["contentChanged"]) {
        watcher.stop()
    }
})

Shell.spawn("sh -c 'sleep 0.2; echo beta >> .smoke_default_watch_dir_helper/state.txt'")
watcher.run()

assert.call(events.count > 0, "expected at least one event from Watcher.watchDir helper")

var matched = false
for (event in events) {
    if (event["path"] == expectedPath && event["contentChanged"]) {
        matched = true
        break
    }
}

assert.call(matched, "expected contentChanged event for watched directory file")
System.print("PASS: default Watcher.watchDir helper smoke test")

if (File.exists(dir)) File.delete(dir)
