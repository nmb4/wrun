import "wrun/file" for File, FileWatcher
import "wrun/process" for Process

var assert = Fn.new { |condition, message|
    if (!condition) {
        System.print("FAIL: %(message)")
        Process.exit(1)
    }
}

var root = ".smoke_non_native_recursive"
var nestedDir = root + "/deep"
var nestedFile = nestedDir + "/state.txt"

if (File.exists(root)) File.delete(root)
File.mkdir(nestedDir)
File.write(nestedFile, "alpha\nbeta\n")

var watcher = FileWatcher.new(root)
    .recursive(true)
    .pollInterval(0.01)
    .diffGranularity("line")
    .diffAlgorithm("myers")
    .includePrettyDiff(true)
    .includePatch(true)
    .start()

File.write(nestedFile, "alpha\nbeta\nnext\n")
Process.sleep(0.05)

var events = watcher.step()
assert.call(events.count > 0, "expected at least one event for nested file change")

var hadContentChange = false
for (event in events) {
    if (event["contentChanged"]) {
        hadContentChange = true
    }
}

assert.call(hadContentChange, "expected at least one contentChanged=true event")
System.print("PASS: non-native watcher recursive mode smoke test")

watcher.stop()
if (File.exists(root)) File.delete(root)
