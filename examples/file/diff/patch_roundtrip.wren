import "wrun/file" for Diff
import "wrun/process" for Process

var path = "config/app.env"
var before = "APP_NAME=wrun\nAPP_MODE=dev\nAPI_PORT=3000\nFEATURE_X=false\n"
var after = "APP_NAME=wrun\nAPP_MODE=prod\nAPI_PORT=3010\nFEATURE_X=true\nFEATURE_Y=true\n"

System.print("=== pretty diff (line) ===")
System.print(Diff.pretty(path, before, after, "line"))

System.print("=== unified patch ===")
var patch = Diff.patch(path, before, after)
System.print(patch)

System.print("=== colored unified patch ===")
System.print(Diff.patchColor(path, before, after))

System.print("=== apply patch result ===")
var applied = Diff.applyPatchResult(before, patch)
if (applied.count < 2) {
    System.print("Unexpected patch result shape")
    Process.exit(1)
}

if (applied[0] != "ok") {
    System.print("Patch apply failed: %(applied[1])")
    Process.exit(1)
}

if (applied[1] != after) {
    System.print("Patch apply mismatch")
    Process.exit(1)
}

System.print("Patch apply verified")
