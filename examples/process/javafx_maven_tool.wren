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
        System.print("  wrun examples/process/javafx_maven_tool.wren <command> [projectDir]")
        System.print("")
        System.print("Commands:")
        System.print("  help     Print this help")
        System.print("  info     Print JavaFX/Maven project config + machine/env info")
        System.print("  doctor   Validate requirements and print missing pieces")
        System.print("  build    Run: mvn clean package -DskipTests")
        System.print("  run      Run: mvn javafx:run")
        System.print("  test     Run: mvn test")
        System.print("  clean    Run: mvn clean")
        System.print("  rebuild  Run: mvn clean package")
        System.print("  watch    Watch src + pom.xml and rebuild on change")
        System.print("")
        System.print("Examples:")
        System.print("  wrun examples/process/javafx_maven_tool.wren info .")
        System.print("  wrun examples/process/javafx_maven_tool.wren run ~/dev/my-javafx-app")
        System.print("  wrun examples/process/javafx_maven_tool.wren watch ~/dev/my-javafx-app")
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
        var result = JavaFxMavenTool.runInteractive(projectDir, command)
        return result["ok"]
    }

    static runWatch(projectDir) {
        var goals = "clean package -DskipTests"
        var runningBuild = false
        var queued = false
        var buildCount = 0

        Log.info("Watch mode started", {
            "project": projectDir,
            "goals": goals,
            "watcher": "Watcher (native-backed)"
        })

        if (!JavaFxMavenTool.runMavenGoals(projectDir, goals)) {
            Log.warn("Initial build failed. Watch mode will continue.")
        }

        var watcher = null
        watcher = Watcher.watchDir(projectDir, Fn.new { |event|
            var path = event["path"]
            var kind = event["kind"]
            var contentChanged = event["contentChanged"]

            if (!JavaFxMavenTool.shouldWatchPath(path)) return
            if (!contentChanged && kind != "created" && kind != "deleted") return

            Log.info("Change detected", {"kind": kind, "path": path})
            queued = true
            if (runningBuild) return

            while (queued) {
                queued = false
                runningBuild = true
                buildCount = buildCount + 1

                Log.info("Rebuild starting", {"count": buildCount})
                var ok = JavaFxMavenTool.runMavenGoals(projectDir, goals)
                runningBuild = false

                if (ok) {
                    Log.info("Rebuild finished", {"count": buildCount, "status": "ok"})
                } else {
                    Log.error("Rebuild failed", {"count": buildCount})
                }
            }
        })
            .pollInterval(0.25)
            .includePrettyDiff(false)
            .includePatch(false)

        watcher.run()
    }
}

var command = Args.count() > 0 ? Str.toLower(Args.get(0)) : "help"
var projectArg = Args.count() > 1 ? Args.get(1) : "."
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
    Log.error("Fix doctor issues before running build/run commands.")
    Process.exit(1)
}

if (command == "build") {
    var ok = JavaFxMavenTool.runMavenGoals(projectDir, "clean package -DskipTests")
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
    JavaFxMavenTool.runWatch(projectDir)
    Process.exit(0)
}

Log.error("Unknown command", {"command": command})
JavaFxMavenTool.usage()
Process.exit(1)
