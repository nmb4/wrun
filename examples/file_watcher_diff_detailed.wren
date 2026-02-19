import "wrun/file" for File, FileWatcher
import "wrun/process" for Process

var path = ".diff_detailed_example.txt"
if (File.exists(path)) File.delete(path)

var before = "title: Demo\nstatus: draft\nowner: alice\nreviewers: 1"
var after = "title: Demo\nstatus: ready\nowner: bob\nreviewers: 2\nrelease: pending"

File.write(path, before)

var watcher = FileWatcher.new(path)
    .recursive(false)
    .start()

File.write(path, after)
Process.sleep(0.05)

var events = watcher.step()
if (events.count == 0) {
    System.print("No change detected")
    if (File.exists(path)) File.delete(path)
    Process.exit(1)
}

var event = events[0]
var diff = event["contentDiff"]
var changedPath = event["path"]
var kind = event["kind"]
var changed = event["contentChanged"]

System.print("Detailed diff for %(changedPath)")
System.print("kind=%(kind) changed=%(changed)")

if (diff == null) {
    System.print("No content diff available")
    if (File.exists(path)) File.delete(path)
    Process.exit(1)
}

var algorithm = diff["algorithm"]
var startLine = diff["startLine"]
var removedCount = diff["removedCount"]
var addedCount = diff["addedCount"]

System.print("algorithm=%(algorithm) startLine=%(startLine)")
System.print("removed (%(removedCount)):")
for (line in diff["removed"]) {
    System.print("  - %(line)")
}

System.print("added (%(addedCount)):")
for (line in diff["added"]) {
    System.print("  + %(line)")
}

if (File.exists(path)) File.delete(path)
