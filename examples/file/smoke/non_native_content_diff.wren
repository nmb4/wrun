import "wrun/file" for File, FileWatcher
import "wrun/process" for Process

var assert = Fn.new { |condition, message|
    if (!condition) {
        System.print("FAIL: %(message)")
        Process.exit(1)
    }
}

var path = ".smoke_file_diff.txt"
if (File.exists(path)) File.delete(path)

File.write(path, "alpha\nbeta\ngamma")

var watcher = FileWatcher.new(path)
    .recursive(false)
    .diffGranularity("line")
    .diffAlgorithm("myers")
    .includePatch(true)
    .includePrettyDiff(true)
    .start()

File.write(path, "alpha\nbeta\nnext\nfinal")
Process.sleep(0.05)

var events = watcher.step()
assert.call(events.count > 0, "expected at least one change event")

var event = events[0]
assert.call(event["kind"] == "modified", "expected modified event")
assert.call(event["contentChanged"], "expected contentChanged=true")

var diff = event["contentDiff"]
assert.call(diff != null, "expected non-null contentDiff")
assert.call(diff["algorithm"] == "line-prefix-suffix", "unexpected diff algorithm")
assert.call(diff["startLine"] == 3, "expected diff start line to be 3")
assert.call(diff["removedCount"] == 1, "expected one removed line")
assert.call(diff["addedCount"] == 2, "expected two added lines")
assert.call(event["prettyDiff"] != null, "expected prettyDiff to be present")
assert.call(event["patch"] != null, "expected unified patch to be present")

System.print("PASS: non-native watcher content diff smoke test")

if (File.exists(path)) File.delete(path)
