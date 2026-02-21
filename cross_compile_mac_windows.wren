import "wrun/args" for Args
import "wrun/env" for Env
import "wrun/file" for Dir, File, Path
import "wrun/print" for Log
import "wrun/process" for Process, Shell
import "wrun/str" for Str

class CrossCompile {
    static usage() {
        System.print("Cross-compile Rust project for macOS + Windows")
        System.print("")
        System.print("Usage:")
        System.print("  wrun examples/process/cross_compile_mac_windows.wren [projectDir] [options]")
        System.print("")
        System.print("Options:")
        System.print("  --debug                Build debug profile (default: --release)")
        System.print("  --clean                Run cargo clean before builds")
        System.print("  --skip-target-add      Skip rustup target add commands")
        System.print("  --windows-target=...   gnu | msvc | full target triple")
        System.print("  -h, --help             Show this help")
        System.print("")
        System.print("Examples:")
        System.print("  wrun examples/process/cross_compile_mac_windows.wren .")
        System.print("  wrun examples/process/cross_compile_mac_windows.wren . --clean")
        System.print("  wrun examples/process/cross_compile_mac_windows.wren . --windows-target=msvc")
    }

    static normalizeWindowsTarget(raw) {
        if (raw == "gnu") return "x86_64-pc-windows-gnu"
        if (raw == "msvc") return "x86_64-pc-windows-msvc"
        return raw
    }

    static commandExists(command) {
        if (Env.os() == "windows") {
            Shell.run("where %(command) > NUL 2>&1")
        } else {
            Shell.run("command -v %(command) >/dev/null 2>&1")
        }
        return Shell.success
    }

    static runStep(label, command) {
        Log.info(label, {"command": command})
        var code = Shell.interactive(command)
        if (code != 0) {
            Log.error("Step failed", {"label": label, "exitCode": code})
            return false
        }
        return true
    }

    static withProjectDir(projectDir, action) {
        var previous = Process.cwd()
        if (!Process.chdir(projectDir)) return false
        var ok = action.call()
        Process.chdir(previous)
        return ok
    }

    static addTargets(targets) {
        for (target in targets) {
            if (!CrossCompile.runStep("Add rust target", "rustup target add %(target)")) {
                return false
            }
        }
        return true
    }

    static buildTargets(targets, releaseBuild) {
        for (target in targets) {
            var cmd = "cargo build --target %(target)"
            if (releaseBuild) cmd = "%(cmd) --release"
            if (!CrossCompile.runStep("Build target", cmd)) {
                return false
            }
        }
        return true
    }
}

var projectDir = "."
var releaseBuild = true
var cleanFirst = false
var skipTargetAdd = false
var windowsTargetRaw = "gnu"
var showHelp = false

for (i in 0...Args.count()) {
    var arg = Args.get(i)
    if (arg == "help" || arg == "--help" || arg == "-h") {
        showHelp = true
    } else if (arg == "--debug") {
        releaseBuild = false
    } else if (arg == "--clean") {
        cleanFirst = true
    } else if (arg == "--skip-target-add") {
        skipTargetAdd = true
    } else if (Str.startsWith(arg, "--windows-target=")) {
        windowsTargetRaw = Str.slice(arg, 17)
    } else if (!Str.startsWith(arg, "--")) {
        projectDir = arg
    } else {
        Log.error("Unknown option", {"arg": arg})
        CrossCompile.usage()
        Process.exit(1)
    }
}

if (showHelp) {
    CrossCompile.usage()
    Process.exit(0)
}

projectDir = Path.absolute(projectDir)
var windowsTarget = CrossCompile.normalizeWindowsTarget(Str.toLower(windowsTargetRaw))
var targets = ["aarch64-apple-darwin", windowsTarget] // "x86_64-apple-darwin",
var profile = releaseBuild ? "release" : "debug"

if (!Dir.exists(projectDir)) {
    Log.error("Project directory does not exist", {"path": projectDir})
    Process.exit(1)
}

if (!File.exists(Path.join(projectDir, "Cargo.toml"))) {
    Log.error("Cargo.toml not found", {"path": Path.join(projectDir, "Cargo.toml")})
    Process.exit(1)
}

if (!CrossCompile.commandExists("cargo")) {
    Log.error("cargo is not available in PATH")
    Process.exit(1)
}

if (!CrossCompile.commandExists("rustup")) {
    Log.error("rustup is not available in PATH")
    Process.exit(1)
}

if (Env.os() != "macos") {
    Log.warn("This script is designed for macOS hosts", {"hostOs": Env.os()})
}

if (windowsTarget == "x86_64-pc-windows-gnu" && !CrossCompile.commandExists("x86_64-w64-mingw32-gcc")) {
    Log.warn("Windows GNU linker not found", {
        "expected": "x86_64-w64-mingw32-gcc",
        "hint": "Install mingw-w64 (for example via Homebrew) or use --windows-target=msvc if your setup supports it."
    })
}

Log.info("Cross-compile plan", {
    "projectDir": projectDir,
    "profile": profile,
    "windowsTarget": windowsTarget,
    "targets": targets.join(", "),
    "skipTargetAdd": skipTargetAdd,
    "cleanFirst": cleanFirst
})

var ok = CrossCompile.withProjectDir(projectDir, Fn.new {
    if (!skipTargetAdd) {
        if (!CrossCompile.addTargets(targets)) return false
    }

    if (cleanFirst) {
        if (!CrossCompile.runStep("Clean project", "cargo clean")) return false
    }

    return CrossCompile.buildTargets(targets, releaseBuild)
})

if (!ok) {
    Log.error("Cross-compile failed")
    Process.exit(1)
}

System.print("")
System.print("Builds completed.")
for (target in targets) {
    System.print("  target/%(target)/%(profile)/")
}
