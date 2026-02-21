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
        System.print("  --mac-universal        Build both mac targets (aarch64 + x86_64)")
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

    static detectMingwPrefix() {
        var explicit = Env.get("MINGW_PREFIX")
        if (explicit != null && Str.trim(explicit) != "" && Dir.exists(explicit)) {
            return explicit
        }

        var candidates = [
            "/opt/homebrew/opt/mingw-w64",
            "/usr/local/opt/mingw-w64"
        ]
        for (path in candidates) {
            if (Dir.exists(path)) return path
        }
        return null
    }

    static detectMingwGccVersion(mingwPrefix) {
        if (mingwPrefix == null) return null
        var root = Path.join(mingwPrefix, "toolchain-x86_64/lib/gcc/x86_64-w64-mingw32")
        if (!Dir.exists(root)) return null

        var versions = Dir.list(root)
        if (versions.count == 0) return null

        var best = versions[0]
        for (version in versions) {
            if (CrossCompile.versionGreater(version, best)) best = version
        }
        return Str.trim(best)
    }

    static versionGreater(a, b) {
        if (a == null) return false
        if (b == null) return true

        var aParts = Str.split(a, ".")
        var bParts = Str.split(b, ".")
        var maxCount = aParts.count > bParts.count ? aParts.count : bParts.count

        for (i in 0...maxCount) {
            var aNum = i < aParts.count ? Num.fromString(aParts[i]) : 0
            var bNum = i < bParts.count ? Num.fromString(bParts[i]) : 0

            if (aNum > bNum) return true
            if (aNum < bNum) return false
        }

        return false
    }

    static windowsGnuEnvPrefix(mingwPrefix, gccVersion) {
        var binDir = Path.join(mingwPrefix, "bin")
        var gcc = Path.join(binDir, "x86_64-w64-mingw32-gcc")
        var gxx = Path.join(binDir, "x86_64-w64-mingw32-g++")
        var ar = Path.join(binDir, "x86_64-w64-mingw32-ar")

        var mingwInclude = Path.join(mingwPrefix, "toolchain-x86_64/x86_64-w64-mingw32/include")
        var gccInclude = Path.join(mingwPrefix, "toolchain-x86_64/lib/gcc/x86_64-w64-mingw32/%(gccVersion)/include")
        var gccIncludeFixed = Path.join(mingwPrefix, "toolchain-x86_64/lib/gcc/x86_64-w64-mingw32/%(gccVersion)/include-fixed")
        var clangArgs = "--target=x86_64-w64-mingw32 -isystem %(mingwInclude) -isystem %(gccInclude) -isystem %(gccIncludeFixed)"

        return "PATH=%(binDir):$PATH CC_x86_64_pc_windows_gnu=%(gcc) CXX_x86_64_pc_windows_gnu=%(gxx) AR_x86_64_pc_windows_gnu=%(ar) CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER=%(gcc) BINDGEN_EXTRA_CLANG_ARGS_x86_64_pc_windows_gnu=\"%(clangArgs)\""
    }

    static addTargets(targets) {
        for (target in targets) {
            if (!CrossCompile.runStep("Add rust target", "rustup target add %(target)")) {
                return false
            }
        }
        return true
    }

    static buildTargets(targets, releaseBuild, windowsGnuEnvPrefix) {
        for (target in targets) {
            var cmd = "cargo build --target %(target)"
            if (releaseBuild) cmd = "%(cmd) --release"

            if (target == "x86_64-pc-windows-gnu" && windowsGnuEnvPrefix != null) {
                cmd = "%(windowsGnuEnvPrefix) %(cmd)"
            }

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
var macUniversal = false

for (i in 0...Args.count()) {
    var arg = Args.get(i)
    if (arg == "help" || arg == "--help" || arg == "-h") {
        showHelp = true
    } else if (arg == "--debug") {
        releaseBuild = false
    } else if (arg == "--clean") {
        cleanFirst = true
    } else if (arg == "--mac-universal") {
        macUniversal = true
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
var hostMacTarget = Env.arch() == "x86_64" ? "x86_64-apple-darwin" : "aarch64-apple-darwin"
var targets = []
if (macUniversal) {
    targets.add("aarch64-apple-darwin")
    targets.add("x86_64-apple-darwin")
} else {
    targets.add(hostMacTarget)
}
targets.add(windowsTarget)
var profile = releaseBuild ? "release" : "debug"
var mingwPrefix = null
var mingwGccVersion = null
var windowsGnuEnvPrefix = null

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

if (windowsTarget == "x86_64-pc-windows-gnu") {
    mingwPrefix = CrossCompile.detectMingwPrefix()
    mingwGccVersion = CrossCompile.detectMingwGccVersion(mingwPrefix)

    if (mingwPrefix == null || mingwGccVersion == null) {
        Log.error("MinGW toolchain not detected for windows-gnu target", {
            "hint": "Install mingw-w64 (brew install mingw-w64) or set MINGW_PREFIX. This is required for bindgen headers (stdlib.h)."
        })
        Process.exit(1)
    }

    windowsGnuEnvPrefix = CrossCompile.windowsGnuEnvPrefix(mingwPrefix, mingwGccVersion)
}

Log.info("Cross-compile plan", {
    "projectDir": projectDir,
    "profile": profile,
    "windowsTarget": windowsTarget,
    "targets": targets.join(", "),
    "skipTargetAdd": skipTargetAdd,
    "cleanFirst": cleanFirst,
    "mingwPrefix": mingwPrefix == null ? "<n/a>" : mingwPrefix,
    "macUniversal": macUniversal
})

var ok = CrossCompile.withProjectDir(projectDir, Fn.new {
    if (!skipTargetAdd) {
        if (!CrossCompile.addTargets(targets)) return false
    }

    if (cleanFirst) {
        if (!CrossCompile.runStep("Clean project", "cargo clean")) return false
    }

    return CrossCompile.buildTargets(targets, releaseBuild, windowsGnuEnvPrefix)
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
