import "wrun/args" for Args
import "wrun/env" for Env
import "wrun/file" for Dir, File, Path, Watcher
import "wrun/print" for Log
import "wrun/process" for Process, Shell
import "wrun/str" for Str

class JavaFxMavenTool {
    static usage() {
        System.print("JavaFX Maven Helper")
        System.print("")
        System.print("Usage:")
        System.print("  wrun mvn.wren <command> [args]")
        System.print("")
        System.print("Commands:")
        System.print("  help     Print this help")
        System.print("  info     Print JavaFX/Maven project config + machine/env info")
        System.print("  doctor   Validate requirements and print missing pieces")
        System.print("  build    Run: mvn clean package -DskipTests")
        System.print("  install  Run: mvn install")
        System.print("  run      Run: mvn javafx:run")
        System.print("  test     Run: mvn test")
        System.print("  clean    Run: mvn clean")
        System.print("  rebuild  Run: mvn clean package")
        System.print("  watch    Watch src + pom.xml, then run: mvn clean compile on change")
        System.print("           add 'run' to restart mvn javafx:run after successful rebuild")
        System.print("  watchrun Alias for: watch run")
        System.print("")
        System.print("Examples:")
        System.print("  wrun mvn.wren info .")
        System.print("  wrun mvn.wren run ~/dev/my-javafx-app")
        System.print("  wrun mvn.wren watch ~/dev/my-javafx-app")
        System.print("  wrun mvn.wren watch run ~/dev/my-javafx-app")
    }

    static isWindows() {
        return Env.os() == "windows"
    }

    static inDir(projectDir, action) {
        var previous = Process.cwd()
        if (!Process.chdir(projectDir)) return null
        var result = action.call()
        Process.chdir(previous)
        return result
    }

    static commandExists(command) {
        if (JavaFxMavenTool.isWindows()) {
            Shell.run("where %(command) > NUL 2>&1")
        } else {
            Shell.run("command -v %(command) >/dev/null 2>&1")
        }
        return Shell.success
    }

    static pomPath(projectDir) {
        return Path.join(projectDir, "pom.xml")
    }

    static readPom(projectDir) {
        var pom = JavaFxMavenTool.pomPath(projectDir)
        if (!File.exists(pom)) return null
        return File.read(pom)
    }

    static mavenCommand(projectDir) {
        if (JavaFxMavenTool.isWindows()) {
            var wrapper = Path.join(projectDir, "mvnw.cmd")
            if (File.exists(wrapper)) return "mvnw.cmd"
            return "mvn"
        }

        var unixWrapper = Path.join(projectDir, "mvnw")
        if (File.exists(unixWrapper)) return "./mvnw"
        return "mvn"
    }

    static mavenAvailable(projectDir) {
        var cmd = JavaFxMavenTool.mavenCommand(projectDir)
        if (Str.contains(cmd, "mvnw")) return true
        return JavaFxMavenTool.commandExists("mvn")
    }

    static runCapture(projectDir, command) {
        var payload = {"ok": false, "stdout": "", "stderr": "", "exitCode": -1}

        JavaFxMavenTool.inDir(projectDir, Fn.new {
            var ok = Shell.run(command)
            payload["ok"] = ok
            payload["stdout"] = Shell.stdout
            payload["stderr"] = Shell.stderr
            payload["exitCode"] = Shell.exitCode
        })

        return payload
    }

    static runInteractive(projectDir, command) {
        var payload = {"ok": false, "exitCode": -1}

        JavaFxMavenTool.inDir(projectDir, Fn.new {
            Log.info("Running command", {"cwd": projectDir, "command": command})
            var code = Shell.interactive(command)
            payload["exitCode"] = code
            payload["ok"] = code == 0
        })

        return payload
    }

    static printCommandFailure(command, result) {
        Log.error("Command failed", {"command": command, "exitCode": result["exitCode"]})
        var stdout = result["stdout"]
        var stderr = result["stderr"]
        var hasStdout = stdout != null && Str.trim(stdout) != ""
        var hasStderr = stderr != null && Str.trim(stderr) != ""

        if (!hasStdout && !hasStderr) {
            System.print("No command output captured.")
            return
        }

        if (hasStdout) {
            System.print("")
            System.print("=== command stdout ===")
            System.print(stdout)
        }

        if (hasStderr) {
            System.print("")
            System.print("=== command stderr ===")
            System.print(stderr)
        }
    }

    static firstTag(xml, tag) {
        if (xml == null) return null

        var open = "<%(tag)>"
        var close = "</%(tag)>"
        var start = Str.indexOf(xml, open)
        if (start == -1) return null

        start = start + open.count
        var tail = Str.slice(xml, start)
        var end = Str.indexOf(tail, close)
        if (end == -1) return null

        return Str.trim(Str.sliceRange(xml, start, start + end))
    }

    static firstTagAfter(xml, tag, afterMarker) {
        if (xml == null) return null

        var markerIndex = Str.indexOf(xml, afterMarker)
        if (markerIndex == -1) return JavaFxMavenTool.firstTag(xml, tag)

        var start = markerIndex + afterMarker.count
        var tail = Str.slice(xml, start)
        return JavaFxMavenTool.firstTag(tail, tag)
    }

    static resolvePomValue(xml, value) {
        if (value == null) return null
        if (!Str.startsWith(value, "${") || !Str.endsWith(value, "}")) return value
        if (value.count < 4) return value

        var key = Str.sliceRange(value, 2, value.count - 1)
        var resolved = JavaFxMavenTool.firstTag(xml, key)
        if (resolved == null) return value

        return "%(value) -> %(resolved)"
    }

    static firstLine(text) {
        if (text == null) return null
        var trimmed = Str.trim(text)
        if (trimmed == "") return null
        var lines = Str.lines(trimmed)
        if (lines.count == 0) return null
        return lines[0]
    }

    static envOrUnset(key) {
        var value = Env.get(key)
        if (value == null) return "<unset>"
        if (Str.trim(value) == "") return "<unset>"
        return value
    }

    static pomSummary(projectDir) {
        var xml = JavaFxMavenTool.readPom(projectDir)
        if (xml == null) return {"hasPom": false}

        var projectSectionStart = "</parent>"
        var groupId = JavaFxMavenTool.firstTagAfter(xml, "groupId", projectSectionStart)
        var artifactId = JavaFxMavenTool.firstTagAfter(xml, "artifactId", projectSectionStart)
        var version = JavaFxMavenTool.firstTagAfter(xml, "version", projectSectionStart)
        var packaging = JavaFxMavenTool.firstTagAfter(xml, "packaging", projectSectionStart)
        if (packaging == null) packaging = "jar (default)"

        var compilerRelease = JavaFxMavenTool.resolvePomValue(xml, JavaFxMavenTool.firstTag(xml, "maven.compiler.release"))
        var compilerSource = JavaFxMavenTool.resolvePomValue(xml, JavaFxMavenTool.firstTag(xml, "maven.compiler.source"))
        var compilerTarget = JavaFxMavenTool.resolvePomValue(xml, JavaFxMavenTool.firstTag(xml, "maven.compiler.target"))
        var javaVersion = JavaFxMavenTool.resolvePomValue(xml, JavaFxMavenTool.firstTag(xml, "java.version"))
        var javafxVersion = JavaFxMavenTool.resolvePomValue(xml, JavaFxMavenTool.firstTag(xml, "javafx.version"))
        var mainClass = JavaFxMavenTool.resolvePomValue(xml, JavaFxMavenTool.firstTag(xml, "mainClass"))
        var pluginConfigured = Str.contains(xml, "<artifactId>javafx-maven-plugin</artifactId>")
        var controlsConfigured = Str.contains(xml, "<artifactId>javafx-controls</artifactId>")

        var effectiveJava = compilerRelease
        if (effectiveJava == null) effectiveJava = javaVersion
        if (effectiveJava == null) effectiveJava = compilerSource

        return {
            "hasPom": true,
            "groupId": groupId,
            "artifactId": artifactId,
            "version": version,
            "packaging": packaging,
            "javaVersion": effectiveJava,
            "javafxVersion": javafxVersion,
            "mainClass": mainClass,
            "pluginConfigured": pluginConfigured,
            "controlsConfigured": controlsConfigured,
            "compilerRelease": compilerRelease,
            "compilerSource": compilerSource,
            "compilerTarget": compilerTarget
        }
    }

    static printInfo(projectDir) {
        var pom = JavaFxMavenTool.pomSummary(projectDir)
        var maven = JavaFxMavenTool.mavenCommand(projectDir)
        var javaInstalled = JavaFxMavenTool.commandExists("java")
        var mavenInstalled = JavaFxMavenTool.mavenAvailable(projectDir)

        System.print("== Project ==")
        System.print("Dir: %(projectDir)")
        System.print("pom.xml: %(pom["hasPom"] ? "yes" : "no")")
        if (pom["hasPom"]) {
            System.print("Coordinates: %(pom["groupId"] == null ? "<missing groupId>" : pom["groupId"]):%(pom["artifactId"] == null ? "<missing artifactId>" : pom["artifactId"]):%(pom["version"] == null ? "<missing version>" : pom["version"])")
            System.print("Packaging: %(pom["packaging"])")
            System.print("Java version (effective): %(pom["javaVersion"] == null ? "<missing>" : pom["javaVersion"])")
            System.print("JavaFX version: %(pom["javafxVersion"] == null ? "<missing>" : pom["javafxVersion"])")
            System.print("Main class: %(pom["mainClass"] == null ? "<missing>" : pom["mainClass"])")
            System.print("JavaFX plugin: %(pom["pluginConfigured"] ? "configured" : "missing")")
            System.print("javafx-controls dep: %(pom["controlsConfigured"] ? "configured" : "missing")")
        }

        System.print("")
        System.print("== Machine + Env ==")
        System.print("OS/Arch: %(Env.os())/%(Env.arch())")
        System.print("User/Home: %(Env.user()) %(Env.home())")
        System.print("JAVA_HOME: %(JavaFxMavenTool.envOrUnset("JAVA_HOME"))")
        System.print("MAVEN_HOME: %(JavaFxMavenTool.envOrUnset("MAVEN_HOME"))")
        System.print("M2_HOME: %(JavaFxMavenTool.envOrUnset("M2_HOME"))")
        System.print("PATH (head): %(Str.truncate(JavaFxMavenTool.envOrUnset("PATH"), 140))")
        System.print("java command: %(javaInstalled ? "found" : "missing")")
        System.print("maven command: %(mavenInstalled ? "found" : "missing")")
        System.print("maven executable: %(maven)")

        var mavenVersion = JavaFxMavenTool.runCapture(projectDir, "%(maven) -v")
        if (mavenVersion["ok"]) {
            System.print("Maven version: %(JavaFxMavenTool.firstLine(mavenVersion["stdout"]))")
        } else {
            System.print("Maven version: <unavailable>")
        }

        var javaVersion = JavaFxMavenTool.runCapture(projectDir, "java -version 2>&1")
        if (javaVersion["ok"]) {
            System.print("Java version: %(JavaFxMavenTool.firstLine(javaVersion["stdout"]))")
        } else {
            System.print("Java version: <unavailable>")
        }
    }

    static doctor(projectDir) {
        var issues = []
        var pom = JavaFxMavenTool.pomSummary(projectDir)

        if (!Dir.exists(projectDir)) {
            issues.add("project directory does not exist: %(projectDir)")
        }

        if (!pom["hasPom"]) {
            issues.add("missing pom.xml")
        }

        if (!JavaFxMavenTool.commandExists("java")) {
            issues.add("java command is not available in PATH")
        }

        if (!JavaFxMavenTool.mavenAvailable(projectDir)) {
            issues.add("maven command is not available (install mvn or add mvnw/mvnw.cmd)")
        }

        if (pom["hasPom"] && !pom["pluginConfigured"]) {
            issues.add("javafx-maven-plugin is missing from pom.xml")
        }

        if (pom["hasPom"] && pom["mainClass"] == null) {
            issues.add("mainClass is not configured in pom.xml")
        }

        if (pom["hasPom"] && pom["javaVersion"] == null) {
            issues.add("java version is not configured (java.version or maven.compiler.*)")
        }

        System.print("== Doctor ==")
        if (issues.count == 0) {
            System.print("OK: core JavaFX Maven requirements look good.")
            return true
        }

        System.print("Found %(issues.count) issue(s):")
        for (issue in issues) {
            System.print("  - %(issue)")
        }
        return false
    }

    static shouldWatchPath(path) {
        if (path == null) return false
        var lower = Str.toLower(path)

        if (Str.endsWith(lower, "/pom.xml") || Str.endsWith(lower, "\\pom.xml")) {
            return true
        }

        if (Str.contains(lower, "/src/") || Str.contains(lower, "\\src\\")) {
            return true
        }

        return false
    }

    static runMavenGoals(projectDir, goals) {
        var command = "%(JavaFxMavenTool.mavenCommand(projectDir)) %(goals)"
        var logFile = JavaFxMavenTool.mavenCommandLogFile(projectDir)
        Log.info("Running Maven (quiet on success)", {"cwd": projectDir, "goals": goals})
        if (File.exists(logFile)) File.delete(logFile)

        // Fallback capture path: keeps Maven output available on failure even if
        // Shell.stdout/stderr are empty on a given shell/platform combination.
        var wrapped = "%(command) > .mvn-command.log 2>&1"
        var result = JavaFxMavenTool.runCapture(projectDir, wrapped)
        if (File.exists(logFile)) {
            var combined = File.read(logFile)
            if (combined != null && Str.trim(combined) != "") {
                if (result["stdout"] == null || Str.trim(result["stdout"]) == "") {
                    result["stdout"] = combined
                }
            }
            if (result["ok"]) File.delete(logFile)
        }

        if (!result["ok"]) {
            JavaFxMavenTool.printCommandFailure(command, result)
        }
        return result["ok"]
    }

    static watchRunPidFile(projectDir) {
        return Path.join(projectDir, ".mvn-watchrun.pid")
    }

    static mavenCommandLogFile(projectDir) {
        return Path.join(projectDir, ".mvn-command.log")
    }

    static watchRunLogFile(projectDir) {
        return Path.join(projectDir, ".mvn-watchrun.log")
    }

    static printWatchRunOutput(projectDir, reason) {
        var logFile = JavaFxMavenTool.watchRunLogFile(projectDir)
        if (!File.exists(logFile)) return
        var text = File.read(logFile)
        if (text == null || Str.trim(text) == "") return

        System.print("")
        System.print("=== watch run output (%(reason)) ===")
        System.print(text)
    }

    static parsePid(text) {
        var line = JavaFxMavenTool.firstLine(text)
        if (line == null) return null
        var pid = Str.trim(line)
        if (!Str.isNumeric(pid)) return null
        return pid
    }

    static readWatchRunPid(projectDir) {
        var pidFile = JavaFxMavenTool.watchRunPidFile(projectDir)
        if (!File.exists(pidFile)) return null
        return JavaFxMavenTool.parsePid(File.read(pidFile))
    }

    static isPidRunning(projectDir, pid) {
        if (pid == null) return false
        var payload = {"running": false}

        JavaFxMavenTool.inDir(projectDir, Fn.new {
            if (JavaFxMavenTool.isWindows()) {
                Shell.run("tasklist /FI \"PID eq %(pid)\" | find \"%(pid)\" > NUL 2>&1")
                payload["running"] = Shell.success
            } else {
                Shell.run("ps -p %(pid) -o state= 2>/dev/null")
                if (!Shell.success) return

                var state = Str.trim(Shell.stdout)
                if (state == "") return

                // 'Z' means zombie/defunct: treat as already stopped for restart semantics.
                if (Str.contains(state, "Z")) return
                payload["running"] = true
            }
        })

        return payload["running"]
    }

    static isWatchRunProcess(projectDir, pid) {
        if (pid == null) return false
        if (JavaFxMavenTool.isWindows()) return JavaFxMavenTool.isPidRunning(projectDir, pid)

        var payload = {"ok": false, "command": ""}
        JavaFxMavenTool.inDir(projectDir, Fn.new {
            Shell.run("ps -p %(pid) -o command=")
            payload["ok"] = Shell.success
            payload["command"] = Shell.stdout
        })

        if (!payload["ok"]) return false
        var lower = Str.toLower(payload["command"])
        return Str.contains(lower, "javafx:run") || Str.contains(lower, "mvnw") || Str.contains(lower, "mvn ")
    }

    static processDebug(projectDir, pid) {
        if (pid == null) return "<none>"

        var payload = {"ok": false, "out": ""}
        JavaFxMavenTool.inDir(projectDir, Fn.new {
            if (JavaFxMavenTool.isWindows()) {
                Shell.run("tasklist /FI \"PID eq %(pid)\"")
                payload["ok"] = Shell.success
                payload["out"] = Str.trim(Shell.stdout)
            } else {
                Shell.run("ps -p %(pid) -o state= -o ppid= -o command= 2>/dev/null")
                payload["ok"] = Shell.success
                payload["out"] = Str.trim(Shell.stdout)
            }
        })

        if (!payload["ok"] || payload["out"] == "") return "<missing>"
        return payload["out"]
    }

    static startWatchRunProcess(projectDir) {
        var pidFile = JavaFxMavenTool.watchRunPidFile(projectDir)
        var logFile = JavaFxMavenTool.watchRunLogFile(projectDir)
        var maven = JavaFxMavenTool.mavenCommand(projectDir)
        if (File.exists(pidFile)) File.delete(pidFile)
        if (File.exists(logFile)) File.delete(logFile)

        var payload = {"started": false}
        JavaFxMavenTool.inDir(projectDir, Fn.new {
            if (JavaFxMavenTool.isWindows()) {
                payload["started"] = Shell.spawn("powershell -NoProfile -Command \"$p = Start-Process -FilePath '%(maven)' -ArgumentList 'javafx:run' -PassThru; Set-Content -Path '.mvn-watchrun.pid' -Value $p.Id\"")
            } else {
                payload["started"] = Shell.spawn("echo $$ > .mvn-watchrun.pid; exec %(maven) javafx:run > .mvn-watchrun.log 2>&1")
            }
        })

        if (!payload["started"]) return null

        var pid = null
        var attempts = 0
        while (pid == null && attempts < 30) {
            attempts = attempts + 1
            Process.sleep(0.1)
            pid = JavaFxMavenTool.readWatchRunPid(projectDir)
        }

        if (!JavaFxMavenTool.isPidRunning(projectDir, pid)) return null
        if (!JavaFxMavenTool.isWatchRunProcess(projectDir, pid)) return null
        return pid
    }

    static stopWatchRunProcess(projectDir, pid) {
        if (pid == null) return true
        if (!JavaFxMavenTool.isPidRunning(projectDir, pid)) return true

        JavaFxMavenTool.inDir(projectDir, Fn.new {
            if (JavaFxMavenTool.isWindows()) {
                Shell.run("taskkill /PID %(pid) /T /F > NUL 2>&1")
            } else {
                Shell.run("kill -TERM %(pid) >/dev/null 2>&1 || true")
                Shell.run("pkill -TERM -P %(pid) >/dev/null 2>&1 || true")
            }
        })

        var attempts = 0
        while (JavaFxMavenTool.isPidRunning(projectDir, pid) && attempts < 20) {
            attempts = attempts + 1
            Process.sleep(0.1)
        }

        if (JavaFxMavenTool.isPidRunning(projectDir, pid)) {
            JavaFxMavenTool.inDir(projectDir, Fn.new {
                if (JavaFxMavenTool.isWindows()) {
                    Shell.run("taskkill /PID %(pid) /T /F > NUL 2>&1")
                } else {
                    Shell.run("kill -KILL %(pid) >/dev/null 2>&1 || true")
                    Shell.run("pkill -KILL -P %(pid) >/dev/null 2>&1 || true")
                }
            })

            var forceAttempts = 0
            while (JavaFxMavenTool.isPidRunning(projectDir, pid) && forceAttempts < 20) {
                forceAttempts = forceAttempts + 1
                Process.sleep(0.1)
            }
        }

        var pidFile = JavaFxMavenTool.watchRunPidFile(projectDir)
        if (File.exists(pidFile)) File.delete(pidFile)
        return !JavaFxMavenTool.isPidRunning(projectDir, pid)
    }

    static printWatchChange(event) {
        var path = event["path"]
        var kind = event["kind"]
        var prettyDiff = event["prettyDiff"]

        Log.info("Change detected", {"kind": kind, "path": path})
        if (prettyDiff != null && Str.trim(prettyDiff) != "") {
            System.print(prettyDiff)
        }
    }

    static runWatch(projectDir) {
        runWatch(projectDir, false)
    }

    static runWatch(projectDir, runApp) {
        var goals = "clean compile"
        var runningCycle = false
        var queued = false
        var buildCount = 0
        var currentPid = null
        var mode = runApp ? "watch + run" : "watch"

        if (runApp) {
            var stalePid = JavaFxMavenTool.readWatchRunPid(projectDir)
            if (JavaFxMavenTool.isWatchRunProcess(projectDir, stalePid)) {
                Log.warn("Stopping stale watchrun process", {"pid": stalePid})
                JavaFxMavenTool.stopWatchRunProcess(projectDir, stalePid)
            } else {
                var stalePidFile = JavaFxMavenTool.watchRunPidFile(projectDir)
                if (File.exists(stalePidFile)) File.delete(stalePidFile)
            }
        }

        Log.info("Watch started", {
            "project": projectDir,
            "goals": goals,
            "mode": mode,
            "watcher": "Watcher (native-backed)"
        })

        var initialBuildOk = JavaFxMavenTool.runMavenGoals(projectDir, goals)
        if (!initialBuildOk) {
            Log.warn("Initial build failed. Watch mode will continue.")
        } else if (runApp) {
            currentPid = JavaFxMavenTool.startWatchRunProcess(projectDir)
            if (currentPid == null) {
                Log.error("Initial app run failed to start. Watch mode will continue.")
                JavaFxMavenTool.printWatchRunOutput(projectDir, "initial start failure")
            } else {
                Log.info("Initial app run started", {"pid": currentPid})
            }
        }

        var watcher = null
        watcher = Watcher.watchDir(projectDir, Fn.new { |event|
            var path = event["path"]
            var kind = event["kind"]
            var contentChanged = event["contentChanged"]

            if (!JavaFxMavenTool.shouldWatchPath(path)) return
            if (!contentChanged && kind != "created" && kind != "deleted") return

            JavaFxMavenTool.printWatchChange(event)
            queued = true
            if (runningCycle) return

            while (queued) {
                queued = false
                runningCycle = true
                buildCount = buildCount + 1

                Log.info("Rebuild starting", {"count": buildCount, "goals": goals})
                var buildOk = JavaFxMavenTool.runMavenGoals(projectDir, goals)
                if (!buildOk) {
                    Log.error("Rebuild failed", {"count": buildCount})
                    runningCycle = false
                    continue
                }

                Log.info("Rebuild finished", {"count": buildCount, "status": "ok"})

                if (runApp) {
                    if (!JavaFxMavenTool.isWatchRunProcess(projectDir, currentPid)) {
                        currentPid = null
                    }

                    if (currentPid != null) {
                        Log.info("Stopping previous app instance", {"count": buildCount, "pid": currentPid})
                        var stopped = JavaFxMavenTool.stopWatchRunProcess(projectDir, currentPid)
                        if (!stopped) {
                            var debug = JavaFxMavenTool.processDebug(projectDir, currentPid)
                            Log.warn("Previous app instance did not stop cleanly", {"count": buildCount, "pid": currentPid, "process": debug})
                        }
                    }

                    currentPid = JavaFxMavenTool.startWatchRunProcess(projectDir)
                    if (currentPid == null) {
                        Log.error("App restart failed", {"count": buildCount})
                        JavaFxMavenTool.printWatchRunOutput(projectDir, "restart failure")
                    } else {
                        Log.info("App restart finished", {"count": buildCount, "status": "ok", "pid": currentPid})
                    }
                }

                runningCycle = false
            }
        })
            .pollInterval(0.25)
            .diffGranularity("line")
            .diffAlgorithm("myers")
            .includePrettyDiff(true)
            .includePatch(false)

        watcher.run()
    }

    static runWatchRun(projectDir) {
        runWatch(projectDir, true)
    }
}

var command = Args.count() > 0 ? Str.toLower(Args.get(0)) : "help"
var projectArg = "."
var watchIncludesRun = command == "watchrun" || command == "watch-run"
var watchCommand = command == "watch" || watchIncludesRun

if (watchCommand) {
    var index = 1
    while (index < Args.count()) {
        var arg = Args.get(index)
        var lowerArg = Str.toLower(arg)
        if (lowerArg == "run") {
            watchIncludesRun = true
        } else if (projectArg == ".") {
            projectArg = arg
        } else {
            Log.warn("Ignoring extra watch argument", {"arg": arg})
        }
        index = index + 1
    }
} else if (Args.count() > 1) {
    projectArg = Args.get(1)
}

var projectDir = Path.absolute(projectArg)

if (command == "help" || command == "-h" || command == "--help") {
    JavaFxMavenTool.usage()
    Process.exit(0)
}

if (!Dir.exists(projectDir)) {
    Log.error("Project directory does not exist", {"path": projectDir})
    Process.exit(1)
}

if (command == "info") {
    JavaFxMavenTool.printInfo(projectDir)
    Process.exit(0)
}

if (command == "doctor") {
    JavaFxMavenTool.printInfo(projectDir)
    var healthy = JavaFxMavenTool.doctor(projectDir)
    Process.exit(healthy ? 0 : 1)
}

var healthy = JavaFxMavenTool.doctor(projectDir)
if (!healthy) {
    Log.error("Fix doctor issues before running build/run/watch commands.")
    Process.exit(1)
}

if (command == "build") {
    var ok = JavaFxMavenTool.runMavenGoals(projectDir, "clean package -DskipTests")
    Process.exit(ok ? 0 : 1)
}

if (command == "install") {
    var ok = JavaFxMavenTool.runMavenGoals(projectDir, "install")
    Process.exit(ok ? 0 : 1)
}

if (command == "run") {
    var ok = JavaFxMavenTool.runMavenGoals(projectDir, "javafx:run")
    Process.exit(ok ? 0 : 1)
}

if (command == "test") {
    var ok = JavaFxMavenTool.runMavenGoals(projectDir, "test")
    Process.exit(ok ? 0 : 1)
}

if (command == "clean") {
    var ok = JavaFxMavenTool.runMavenGoals(projectDir, "clean")
    Process.exit(ok ? 0 : 1)
}

if (command == "rebuild") {
    var ok = JavaFxMavenTool.runMavenGoals(projectDir, "clean package")
    Process.exit(ok ? 0 : 1)
}

if (command == "watch") {
    JavaFxMavenTool.runWatch(projectDir, watchIncludesRun)
    Process.exit(0)
}

if (command == "watchrun" || command == "watch-run") {
    JavaFxMavenTool.runWatch(projectDir, true)
    Process.exit(0)
}

Log.error("Unknown command", {"command": command})
JavaFxMavenTool.usage()
Process.exit(1)
