import "wrun/file" for File, FileWatcher
import "wrun/process" for Process

var path = ".diff_simple_example.txt"
if (File.exists(path)) File.delete(path)

File.write(path, "alpha\nbeta\ngamma")

var watcher = FileWatcher.new(path)
    .recursive(false)
    .start()

File.write(path, "alpha\nbeta updated\ngamma")
Process.sleep(0.05)

var events = watcher.step()
if (events.count == 0) {
    System.print("No change detected")
    if (File.exists(path)) File.delete(path)
    Process.exit(1)
}

var event = events[0]
var diff = event["contentDiff"]
var kind = event["kind"]
var changedPath = event["path"]
var changed = event["contentChanged"]

System.print("kind=%(kind) path=%(changedPath)")
System.print("contentChanged=%(changed)")
if (diff != null) {
    var startLine = diff["startLine"]
    var addedCount = diff["addedCount"]
    var removedCount = diff["removedCount"]
    System.print("startLine=%(startLine) +%(addedCount) -%(removedCount)")
}

if (File.exists(path)) File.delete(path)
