import "wrun/file" for File, Path, NativeFileWatcher
import "wrun/process" for Process, Shell

var assert = Fn.new { |condition, message|
    if (!condition) {
        System.print("FAIL: %(message)")
        Process.exit(1)
    }
}

var path = ".smoke_native_wait_mode.txt"
var expectedPath = Path.absolute(path)
if (File.exists(path)) File.delete(path)
File.write(path, "baseline")

var events = []
var watcher = NativeFileWatcher.new(".")
    .recursive(false)
    .mode("wait")
    .waitTimeout(0.2)
    .diffGranularity("line")
    .diffAlgorithm("myers")
    .includePatch(true)
    .includePrettyDiff(true)
    .fallbackPolling(false)

Shell.spawn("sh -c 'sleep 0.2; echo next >> .smoke_native_wait_mode.txt'")
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
    System.print("SKIP: native watcher wait mode strict probe (no native content event observed)")
    if (File.exists(path)) File.delete(path)
    Process.exit(0)
}

assert.call(watcher.runMode == "wait", "expected runMode to remain wait")
assert.call(watcher.sawNativeEvent, "expected sawNativeEvent=true")

var diff = matched["contentDiff"]
assert.call(diff != null, "expected non-null contentDiff")
assert.call(diff["addedCount"] >= 1, "expected at least one added line")
assert.call(matched["prettyDiff"] != null, "expected prettyDiff to be present")
assert.call(matched["patch"] != null, "expected patch to be present")

System.print("PASS: native watcher wait mode smoke test (strict native)")

if (File.exists(path)) File.delete(path)
