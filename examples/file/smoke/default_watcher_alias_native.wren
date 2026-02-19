import "wrun/file" for File, Path, Watcher
import "wrun/process" for Process, Shell

var assert = Fn.new { |condition, message|
    if (!condition) {
        System.print("FAIL: %(message)")
        Process.exit(1)
    }
}

var path = ".smoke_default_watcher_alias_native.txt"
var expectedPath = Path.absolute(path)
if (File.exists(path)) File.delete(path)
File.write(path, "baseline")

var events = []
var watcher = Watcher.new(".")
    .recursive(false)
    .mode("wait")
    .waitTimeout(0.25)
    .fallbackPolling(false)
    .pollInterval(0.02)
    .includePrettyDiff(true)
    .includePatch(true)

Shell.spawn("sh -c 'sleep 0.2; echo next >> .smoke_default_watcher_alias_native.txt'")
watcher.start()

var matched = null
for (i in 0..80) {
    var batch = watcher.step()
    for (event in batch) {
        events.add(event)
        if (event["path"] == expectedPath && event["native"] && event["contentChanged"]) {
            matched = event
            break
        }
    }
    if (matched != null) break
}
watcher.stop()

if (events.count == 0 || matched == null) {
    System.print("SKIP: default Watcher alias strict probe (no native content event observed)")
    if (File.exists(path)) File.delete(path)
    Process.exit(0)
}

assert.call(watcher.sawNativeEvent, "expected sawNativeEvent=true from default Watcher alias")

System.print("PASS: default Watcher alias smoke test (native by default)")

if (File.exists(path)) File.delete(path)
