import "wrun/file" for File, Watcher
import "wrun/process" for Process, Shell

var assert = Fn.new { |condition, message|
    if (!condition) {
        System.print("FAIL: %(message)")
        Process.exit(1)
    }
}

var path = ".smoke_default_watch_file_helper.txt"
if (File.exists(path)) File.delete(path)
File.write(path, "one\ntwo\n")

var events = []
var watcher = null
watcher = Watcher.watchFile(path, Fn.new { |event|
    events.add(event)
    if (event["contentChanged"]) {
        watcher.stop()
    }
})

Shell.spawn("sh -c 'sleep 0.2; echo three >> .smoke_default_watch_file_helper.txt'")
watcher.run()

assert.call(events.count > 0, "expected at least one event from Watcher.watchFile helper")

var sawContentChanged = false
for (event in events) {
    if (event["contentChanged"]) {
        sawContentChanged = true
    }
}
assert.call(sawContentChanged, "expected contentChanged=true from Watcher.watchFile helper")

System.print("PASS: default Watcher.watchFile helper smoke test")

if (File.exists(path)) File.delete(path)
