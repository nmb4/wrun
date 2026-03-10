import "wrun/args" for Args
import "wrun/env" for Env
import "wrun/pipeline" for Pipeline
import "wrun/print" for Log
import "wrun/process" for Process, Shell
import "wrun/str" for Str

class DeployLocal {
    static usage() {
        System.print("Spacebot local deploy (Mac mini) with Pipeline build ETA")
        System.print("")
        System.print("Usage:")
        System.print("  wrun deploy_macmini_pipeline.wren [options]")
        System.print("")
        System.print("Options:")
        System.print("  --project-dir=...       Spacebot repo path (default: ~/dev/spacebot)")
        System.print("  --binary=...            Binary name (default: spacebot)")
        System.print("  --service-label=...     launchd label (default: com.spacebot)")
        System.print("  --api-port=...          API/UI port (default: 19898)")
        System.print("  --timing-key=...        Build timing key (default: spacebot-release-build)")
        System.print("  --timings-dir=...       Timing storage dir (default: ~/.wrun/pipeline_timings)")
        System.print("  --skip-ui-install       Skip npm install step")
        System.print("  --skip-ui-build         Skip npm build step")
        System.print("  --skip-restart          Skip launchd restart + health checks")
        System.print("  -h, --help              Show this help")
        System.print("")
        System.print("Example:")
        System.print("  wrun deploy_macmini_pipeline.wren --project-dir=~/dev/spacebot")
    }

    static shellQuote(value) {
        var escaped = Str.replaceAll(value, "'", """'"'"'""")
        return "'%(escaped)'"
    }

    static commandExists(command) {
        Shell.run("export PATH=\"$HOME/.cargo/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH\"; command -v %(command) >/dev/null 2>&1")
        return Shell.success
    }

    static addStep(pipeline, previousName, name, command) {
        if (previousName == null) {
            pipeline.task(name, command)
        } else {
            pipeline.after(previousName, name, command)
        }
        pipeline.failureMode(name, "stop")
        return name
    }
}

var projectDir = "%(Env.home())/dev/spacebot"
var binaryName = "spacebot"
var serviceLabel = "com.spacebot"
var apiPort = "19898"
var timingKey = "spacebot-release-build"
var timingsDir = "%(Env.home())/.wrun/pipeline_timings"
var skipUiInstall = false
var skipUiBuild = false
var skipRestart = false
var showHelp = false

for (i in 0...Args.count()) {
    var arg = Args.get(i)
    if (arg == "-h" || arg == "--help" || arg == "help") {
        showHelp = true
    } else if (arg == "--skip-ui-install") {
        skipUiInstall = true
    } else if (arg == "--skip-ui-build") {
        skipUiBuild = true
    } else if (arg == "--skip-restart") {
        skipRestart = true
    } else if (Str.startsWith(arg, "--project-dir=")) {
        projectDir = Str.slice(arg, 14)
    } else if (Str.startsWith(arg, "--binary=")) {
        binaryName = Str.slice(arg, 9)
    } else if (Str.startsWith(arg, "--service-label=")) {
        serviceLabel = Str.slice(arg, 16)
    } else if (Str.startsWith(arg, "--api-port=")) {
        apiPort = Str.slice(arg, 11)
    } else if (Str.startsWith(arg, "--timing-key=")) {
        timingKey = Str.slice(arg, 13)
    } else if (Str.startsWith(arg, "--timings-dir=")) {
        timingsDir = Str.slice(arg, 14)
    } else {
        Log.error("Unknown option", {"arg": arg})
        DeployLocal.usage()
        Process.exit(1)
    }
}

if (showHelp) {
    DeployLocal.usage()
    Process.exit(0)
}

if (Env.os() != "macos") {
    Log.error("This script is intended for macOS hosts", {"hostOs": Env.os()})
    Process.exit(1)
}

if (!DeployLocal.commandExists("cargo")) {
    Log.error("cargo not found in PATH")
    Process.exit(1)
}

if (!skipUiInstall || !skipUiBuild) {
    if (!DeployLocal.commandExists("node")) {
        Log.error("node not found in PATH", {"hint": "Ensure /opt/homebrew/bin is in PATH"})
        Process.exit(1)
    }
    if (!DeployLocal.commandExists("npm")) {
        Log.error("npm not found in PATH", {"hint": "Ensure /opt/homebrew/bin is in PATH"})
        Process.exit(1)
    }
}

var pathSetup = "export PATH=\"$HOME/.cargo/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH\""
var projectQ = DeployLocal.shellQuote(projectDir)

var uiInstallCmd = "%(pathSetup); cd %(projectQ)/interface && npm install --package-lock=false"
var uiBuildCmd = "%(pathSetup); cd %(projectQ)/interface && npm run build"
var rustBuildCmd = "%(pathSetup); cd %(projectQ) && touch src/api/server.rs && cargo build --release --bin %(binaryName)"
var installCmd = "%(pathSetup); cd %(projectQ) && install -m 0755 target/release/%(binaryName) \"$HOME/.cargo/bin/%(binaryName).new\" && mv \"$HOME/.cargo/bin/%(binaryName).new\" \"$HOME/.cargo/bin/%(binaryName)\""
var restartCmd = "%(pathSetup); uid=$(id -u); target=\"gui/$uid/%(serviceLabel)\"; plist=\"$HOME/Library/LaunchAgents/%(serviceLabel).plist\"; [ -f \"$plist\" ] || { echo \"Missing $plist\" >&2; exit 1; }; launchctl bootout \"$target\" >/dev/null 2>&1 || true; launchctl bootstrap \"gui/$uid\" \"$plist\" >/dev/null 2>&1 || true; launchctl kickstart -k \"$target\" >/dev/null 2>&1 || launchctl start \"$target\" >/dev/null 2>&1 || true"
var waitApiCmd = "%(pathSetup); for _ in $(seq 1 20); do if /usr/bin/curl -fsS http://127.0.0.1:%(apiPort)/api/health >/dev/null 2>&1; then exit 0; fi; sleep 1; done; echo \"spacebot api health did not become ready on port %(apiPort)\" >&2; exit 1"
var verifyUiCmd = "%(pathSetup); hdr=\"/tmp/spacebot_ui_headers.$$\"; /usr/bin/curl -sS -D \"$hdr\" -o /dev/null http://127.0.0.1:%(apiPort)/; line=$(/usr/bin/head -n 1 \"$hdr\" 2>/dev/null || true); /bin/rm -f \"$hdr\"; echo \"$line\" | /usr/bin/grep -q \" 200 \" || { echo \"web ui returned unexpected status: $line\" >&2; exit 1; }"
var statusCmd = "%(pathSetup); /usr/bin/curl -fsS http://127.0.0.1:%(apiPort)/api/status"

Log.info("Local deploy plan", {
    "projectDir": projectDir,
    "binary": binaryName,
    "serviceLabel": serviceLabel,
    "apiPort": apiPort,
    "timingKey": timingKey,
    "timingsDir": timingsDir,
    "skipUiInstall": skipUiInstall,
    "skipUiBuild": skipUiBuild,
    "skipRestart": skipRestart
})

var p = Pipeline.new()
    .pollInterval(0.1)
    .timingsDir(timingsDir)

var prev = null

if (!skipUiInstall) {
    prev = DeployLocal.addStep(p, prev, "ui-install", uiInstallCmd)
}

if (!skipUiBuild) {
    prev = DeployLocal.addStep(p, prev, "ui-build", uiBuildCmd)
}

prev = DeployLocal.addStep(p, prev, "build", rustBuildCmd)
p.buildStep("build", timingKey)

prev = DeployLocal.addStep(p, prev, "install", installCmd)

if (!skipRestart) {
    prev = DeployLocal.addStep(p, prev, "restart", restartCmd)
    prev = DeployLocal.addStep(p, prev, "wait-api", waitApiCmd)
    prev = DeployLocal.addStep(p, prev, "verify-ui", verifyUiCmd)
    prev = DeployLocal.addStep(p, prev, "status", statusCmd)
}

p.onFail("wait-api", Fn.new { |result|
    var text = Str.trim(result.stdout)
    if (text != "") {
        Log.info("wait for api failed", {"stdout": text})
    }
})

p.onSuccess("status", Fn.new { |result|
    var text = Str.trim(result.stdout)
    if (text != "") {
        Log.info("Service status", {"json": text})
    }
})

p.onFail("build", Fn.new { |result|
    Log.error("Build failed", {"exitCode": result.exitCode, "stderr": result.stderr})
})

p.onFail("verify-ui", Fn.new { |result|
    Log.error("UI verification failed", {"stderr": result.stderr})
})

var outcome = p.run()

if (!outcome.success) {
    if (outcome.aborted) {
        Log.error("Deploy aborted due to failure")
    } else {
        Log.error("Deploy finished with failures")
    }
    Process.exit(1)
}

Log.info("Deploy complete", {"success": true})
