// Pipeline - Async command orchestration library for wrun
//
// Features:
// - Run commands in parallel or sequentially
// - Define dependencies between commands
// - Configure failure behavior (continue, stop, ignore)
// - Final "join" command with configurable execution policy
//
// Example:
//   Pipeline.new()
//     .task("github", "gh repo create myrepo --public --source=. --push")
//     .task("readme", "claude -p 'Generate README'")
//     .after("github", "vercel", "vercel --prod --yes")
//     .after("vercel", "domain", "vercel domains add example.com")
//     .finally("git push")
//     .onSuccess("readme") { |result| File.write("README.md", result.stdout) }
//     .run()

import "wrun/process" for Shell, Process
import "wrun/print" for Log
import "wrun/file" for File
import "wrun/env" for Env
import "wrun/str" for Str

// Result of a completed task
class TaskResult {
  construct new(name, exitCode, stdout, stderr) {
    _name = name
    _exitCode = exitCode
    _stdout = stdout
    _stderr = stderr
  }

  name { _name }
  exitCode { _exitCode }
  stdout { _stdout }
  stderr { _stderr }
  success { _exitCode == 0 }

  toString { "TaskResult(%(name), code=%(exitCode), success=%(success))" }
}

// Represents a single task in the pipeline
class Task {
  construct new(name, command) {
    _name = name
    _command = command
    _dependencies = []      // Names of tasks that must complete first
    _onFailure = "continue" // "continue", "stop", "ignore"
    _handle = null
    _started = false
    _done = false
    _result = null
    _onSuccessCallback = null
    _onFailureCallback = null
    _logLevel = "trace"     // Log level for this task
    _isBuildStep = false
    _timingKey = null
    _liveTimer = false
    _startedAt = 0
    _lastTimerSecond = -1
    _expectedSeconds = null
    _historyCount = 0
  }

  name { _name }
  command { _command }
  dependencies { _dependencies }
  onFailure { _onFailure }
  handle { _handle }
  handle=(v) { _handle = v }
  started { _started }
  started=(v) { _started = v }
  done { _done }
  done=(v) { _done = v }
  result { _result }
  result=(v) { _result = v }
  success { _result != null && _result.success }
  logLevel { _logLevel }
  isBuildStep { _isBuildStep }
  timingKey { _timingKey }
  liveTimer { _liveTimer }
  startedAt { _startedAt }
  startedAt=(v) { _startedAt = v }
  lastTimerSecond { _lastTimerSecond }
  lastTimerSecond=(v) { _lastTimerSecond = v }
  expectedSeconds { _expectedSeconds }
  expectedSeconds=(v) { _expectedSeconds = v }
  historyCount { _historyCount }
  historyCount=(v) { _historyCount = v }

  // Add a dependency - this task runs after the named task
  after(taskName) {
    _dependencies.add(taskName)
    return this
  }

  // Set failure behavior: "continue" (default), "stop", or "ignore"
  // - continue: other tasks keep running, but pipeline is marked failed
  // - stop: abort all pending tasks immediately
  // - ignore: treat failure as success for dependency purposes
  failureMode(mode) {
    _onFailure = mode
    return this
  }

  // Set log level for this task: "trace", "debug", "info", "warn", "error", or custom
  log(level) {
    _logLevel = level
    return this
  }

  // Mark this task as a build step and enable timing persistence + ETA.
  buildStep() {
    _isBuildStep = true
    _timingKey = _name
    _liveTimer = true
    return this
  }

  // Use a custom key when sharing timing history across multiple task names.
  buildStep(key) {
    _isBuildStep = true
    _timingKey = key
    _liveTimer = true
    return this
  }

  // Toggle live elapsed/ETA logging for build steps.
  liveTimer(enabled) {
    _liveTimer = enabled
    return this
  }

  // Callback when task succeeds
  onSuccess(fn) {
    _onSuccessCallback = fn
    return this
  }

  // Callback when task fails
  onFail(fn) {
    _onFailureCallback = fn
    return this
  }

  // Internal: invoke callbacks
  invokeCallbacks() {
    if (_result == null) return
    if (_result.success && _onSuccessCallback != null) {
      _onSuccessCallback.call(_result)
    } else if (!_result.success && _onFailureCallback != null) {
      _onFailureCallback.call(_result)
    }
  }
}

// Main pipeline orchestrator
class Pipeline {
  construct new() {
    _tasks = {}           // name -> Task
    _order = []           // insertion order for iteration
    _finally = null       // final command to run
    _finallyMode = "success" // "success", "always", "failure"
    _pollInterval = 0.05  // seconds between polls
    _verbose = true       // log task start/completion
    _results = {}         // name -> TaskResult
    _aborted = false
    _timingsDir = "%(Env.home())/.wrun/pipeline_timings"
  }

  // Add a task with no dependencies (runs immediately)
  task(name, command) {
    var t = Task.new(name, command)
    _tasks[name] = t
    _order.add(name)
    return this
  }

  // Add a task that runs after another task completes
  after(dependency, name, command) {
    var t = Task.new(name, command)
    t.after(dependency)
    _tasks[name] = t
    _order.add(name)
    return this
  }

  // Add a task that runs after multiple tasks complete
  afterAll(dependencies, name, command) {
    var t = Task.new(name, command)
    for (dep in dependencies) {
      t.after(dep)
    }
    _tasks[name] = t
    _order.add(name)
    return this
  }

  // Get a task for further configuration
  configure(name) {
    return _tasks[name]
  }

  // Set callback for when a task succeeds
  onSuccess(name, fn) {
    if (_tasks.containsKey(name)) {
      _tasks[name].onSuccess(fn)
    }
    return this
  }

  // Set callback for when a task fails
  onFail(name, fn) {
    if (_tasks.containsKey(name)) {
      _tasks[name].onFail(fn)
    }
    return this
  }

  // Set failure mode for a task
  failureMode(name, mode) {
    if (_tasks.containsKey(name)) {
      _tasks[name].failureMode(mode)
    }
    return this
  }

  // Mark an existing task as a build step with timing persistence + ETA.
  buildStep(name) {
    if (_tasks.containsKey(name)) {
      _tasks[name].buildStep()
    }
    return this
  }

  // Mark an existing task as a build step with a custom timing key.
  buildStep(name, timingKey) {
    if (_tasks.containsKey(name)) {
      _tasks[name].buildStep(timingKey)
    }
    return this
  }

  // Set the final command that runs after all tasks
  // mode: "success" (only if all succeeded), "always", "failure" (only if something failed)
  finally(command) {
    _finally = command
    return this
  }

  finallyMode(mode) {
    _finallyMode = mode
    return this
  }

  // Set poll interval in seconds
  pollInterval(seconds) {
    _pollInterval = seconds
    return this
  }

  // Set where build-step timing history is persisted.
  timingsDir(path) {
    _timingsDir = path
    return this
  }

  // Enable/disable verbose logging
  verbose(enabled) {
    _verbose = enabled
    return this
  }

  // Check if all dependencies for a task are satisfied
  dependenciesSatisfied_(task) {
    for (depName in task.dependencies) {
      if (!_tasks.containsKey(depName)) {
        Log.warn("Unknown dependency: %(depName) for task %(task.name)")
        return false
      }
      var dep = _tasks[depName]
      if (!dep.done) return false
      // If dependency failed and its mode is "stop", we can't proceed
      if (!dep.success && dep.onFailure == "stop") return false
    }
    return true
  }

  // Check if any dependency failed with "stop" mode
  shouldAbort_() {
    for (name in _order) {
      var task = _tasks[name]
      if (task.done && !task.success && task.onFailure == "stop") {
        return true
      }
    }
    return false
  }

  // Check if all tasks are done
  allDone_() {
    for (name in _order) {
      if (!_tasks[name].done) return false
    }
    return true
  }

  // Check if all tasks succeeded
  allSucceeded_() {
    for (name in _order) {
      var task = _tasks[name]
      if (!task.success && task.onFailure != "ignore") return false
    }
    return true
  }

  // Check if any task failed (not ignored)
  anyFailed_() {
    for (name in _order) {
      var task = _tasks[name]
      if (!task.success && task.onFailure != "ignore") return true
    }
    return false
  }

  ensureTimingsDir_() {
    if (File.isDirectory(_timingsDir)) return true
    return File.mkdir(_timingsDir)
  }

  sanitizeTimingKey_(key) {
    var out = ""
    for (ch in key) {
      if (Str.isAlphaNumeric(ch) || ch == "-" || ch == "_") {
        out = "%(out)%(ch)"
      } else {
        out = "%(out)_"
      }
    }
    if (out == "") return "task"
    return out
  }

  timingFilePath_(task) {
    var rawKey = task.timingKey != null ? task.timingKey : task.name
    var safeKey = sanitizeTimingKey_(rawKey)
    return "%(_timingsDir)/%(safeKey).timings"
  }

  loadDurations_(task) {
    var values = []
    if (!ensureTimingsDir_()) return values

    var path = timingFilePath_(task)
    if (!File.exists(path)) return values

    var content = File.read(path)
    if (content == null || content == "") return values

    for (line in Str.lines(content)) {
      var t = Str.trim(line)
      if (t == "") continue
      var n = Num.fromString(t)
      if (n != null && n >= 0) {
        values.add(n)
      }
    }

    return values
  }

  average_(values) {
    if (values.count == 0) return null
    var sum = 0
    for (v in values) {
      sum = sum + v
    }
    return sum / values.count
  }

  persistDuration_(task, durationSeconds) {
    if (!ensureTimingsDir_()) {
      if (_verbose) Log.warn("Could not create timing directory", {"path": _timingsDir})
      return
    }

    var path = timingFilePath_(task)
    var line = "%(durationSeconds)\n"
    if (File.exists(path)) {
      if (!File.append(path, line) && _verbose) {
        Log.warn("Failed to append build timing", {"task": task.name, "path": path})
      }
    } else {
      if (!File.write(path, line) && _verbose) {
        Log.warn("Failed to write build timing", {"task": task.name, "path": path})
      }
    }
  }

  formatDuration_(seconds) {
    var safe = seconds
    if (safe < 0) safe = 0

    var whole = safe.floor
    var mins = (whole / 60).floor
    var secs = whole % 60
    var secsText = secs < 10 ? "0%(secs)" : "%(secs)"
    return "%(mins)m %(secsText)s"
  }

  updateLiveTimers_() {
    if (!_verbose) return

    for (name in _order) {
      var task = _tasks[name]
      if (!task.isBuildStep) continue
      if (!task.liveTimer) continue
      if (!task.started || task.done) continue
      if (task.handle == 0 || task.handle == null) continue

      var elapsed = Process.now() - task.startedAt
      if (elapsed < 0) elapsed = 0
      var tick = elapsed.floor
      if (tick <= task.lastTimerSecond) continue

      task.lastTimerSecond = tick

      var progress = null
      var etaTotal = null

      if (task.expectedSeconds != null && task.expectedSeconds > 0) {
        progress = ((elapsed / task.expectedSeconds) * 100).floor
        if (progress > 100) progress = 100
        etaTotal = task.expectedSeconds
      }

      var liveColor = "green"
      if (task.expectedSeconds != null && task.expectedSeconds > 0) {
        var eta = task.expectedSeconds
        var blueStart = eta - 1
        if (blueStart < 0) blueStart = 0
        var redStart = eta * 1.5

        if (elapsed < blueStart) {
          liveColor = "green"
        } else if (elapsed <= eta) {
          liveColor = "blue"
        } else if (elapsed < redStart) {
          liveColor = "yellow"
        } else {
          liveColor = "red"
        }
      }

      var elapsedText = formatDuration_(elapsed)
      var message = null
      if (etaTotal != null && progress != null) {
        var progressText = "%(progress)" + "\%"
        var etaText = formatDuration_(etaTotal)
        message = "%(task.name) %(elapsedText)/%(etaText) %(progressText)"
      } else {
        message = "%(task.name) -- %(elapsedText)/--"
      }

      Log.liveColor("live", message, liveColor)
    }
  }

  // Start a task
  startTask_(task) {
    task.started = true
    task.startedAt = Process.now()
    task.lastTimerSecond = -1

    if (task.isBuildStep) {
      var history = loadDurations_(task)
      task.historyCount = history.count
      task.expectedSeconds = average_(history)
    } else {
      task.historyCount = 0
      task.expectedSeconds = null
    }

    task.handle = Shell.spawnAsync(task.command)
    if (task.handle == 0) {
      // Failed to spawn
      task.done = true
      task.result = TaskResult.new(task.name, -1, "", "Failed to spawn process")
      if (_verbose) Log.error("Failed to start task", {"task": task.name})
    } else {
      if (_verbose) {
        if (task.isBuildStep) {
          var kv = {
            "task": task.name,
            "samples": task.historyCount
          }
          if (task.expectedSeconds != null) {
            kv["eta"] = formatDuration_(task.expectedSeconds)
          } else {
            kv["eta"] = "unknown"
          }
          Log.custom(task.logLevel, "Started build step", kv)
        } else {
          Log.custom(task.logLevel, "Started", {"task": task.name})
        }
      }
    }
  }

  // Complete a task
  completeTask_(task) {
    task.done = true
    var duration = Process.now() - task.startedAt
    if (duration < 0) duration = 0
    var code = Shell.getExitCode(task.handle)
    var stdout = Shell.getStdout(task.handle)
    var stderr = Shell.getStderr(task.handle)
    Shell.cleanup(task.handle)

    task.result = TaskResult.new(task.name, code, stdout, stderr)
    _results[task.name] = task.result

    if (task.isBuildStep) {
      persistDuration_(task, duration)
    }

    if (task.success) {
      if (_verbose) {
        if (task.isBuildStep) {
          Log.custom(task.logLevel, "Completed build step", {
            "task": task.name,
            "exitCode": code,
            "duration": formatDuration_(duration)
          })
        } else {
          Log.custom(task.logLevel, "Completed", {"task": task.name, "exitCode": code})
        }
      }
    } else {
      if (_verbose) {
        if (task.isBuildStep) {
          Log.warn("Failed build step", {
            "task": task.name,
            "exitCode": code,
            "duration": formatDuration_(duration)
          })
        } else {
          Log.warn("Failed", {"task": task.name, "exitCode": code})
        }
      }
    }

    task.invokeCallbacks()
  }

  // Main execution loop
  run() {
    if (_verbose) Log.custom("trace", "Pipeline starting", {"tasks": this.taskCount})

    // Main event loop
    while (!allDone_() && !_aborted) {
      // Check for abort condition
      if (shouldAbort_()) {
        _aborted = true
        if (_verbose) Log.error("Pipeline aborted", {"reason": "task failure"})
        break
      }

      // Start tasks whose dependencies are satisfied
      for (name in _order) {
        var task = _tasks[name]
        if (!task.started && !task.done && dependenciesSatisfied_(task)) {
          startTask_(task)
        }
      }

      // Check running tasks for completion
      for (name in _order) {
        var task = _tasks[name]
        if (task.started && !task.done && task.handle != 0) {
          if (Shell.isDone(task.handle)) {
            completeTask_(task)
          }
        }
      }

      updateLiveTimers_()

      // Small sleep to avoid busy-waiting
      if (!allDone_()) {
        Shell.exec("sleep %(_pollInterval)")
      }
    }

    // Run finally command if configured
    if (_finally != null) {
      var shouldRun = false
      if (_finallyMode == "always") {
        shouldRun = true
      } else if (_finallyMode == "success" && allSucceeded_() && !_aborted) {
        shouldRun = true
      } else if (_finallyMode == "failure" && (anyFailed_() || _aborted)) {
        shouldRun = true
      }

      if (shouldRun) {
        if (_verbose) Log.custom("trace", "Running finally", {"command": _finally})
        var code = Shell.exec(_finally)
        if (code == 0) {
          if (_verbose) Log.custom("trace", "Finally completed", {"exitCode": code})
        } else {
          if (_verbose) Log.warn("Finally failed", {"exitCode": code})
        }
      }
    }

    if (_verbose) {
      if (_aborted) {
        Log.error("Pipeline aborted", {"success": false})
      } else if (allSucceeded_()) {
        Log.custom("trace", "Pipeline completed", {"success": true})
      } else {
        Log.warn("Pipeline completed", {"success": false})
      }
    }

    return PipelineResult.new(_results, allSucceeded_(), _aborted)
  }

  // Get task count
  taskCount { _order.count }

  // Get results after run
  results { _results }
}

// Result of pipeline execution
class PipelineResult {
  construct new(results, success, aborted) {
    _results = results
    _success = success
    _aborted = aborted
  }

  results { _results }
  success { _success }
  aborted { _aborted }

  // Get result for a specific task
  [name] { _results[name] }

  // Check if a specific task succeeded
  succeeded(name) {
    return _results.containsKey(name) && _results[name].success
  }

  toString {
    if (_aborted) return "PipelineResult(aborted)"
    if (_success) return "PipelineResult(success)"
    return "PipelineResult(failed)"
  }
}

// Convenience builder for common patterns
class Parallel {
  // Run multiple commands in parallel, return when all complete
  // Set showOutput to true to print stdout/stderr from each task
  static run(commands) { run(commands, false) }
  static run(commands, showOutput) {
    var p = Pipeline.new().verbose(false)
    var i = 0
    for (cmd in commands) {
      var name = "task_%(i)"
      p.task(name, cmd)
      if (showOutput) {
        p.onSuccess(name, Fn.new { |r|
          var out = r.stdout.trim()
          if (out != "") System.print(out)
        })
        p.onFail(name, Fn.new { |r|
          var err = r.stderr.trim()
          if (err != "") System.print(err)
        })
      }
      i = i + 1
    }
    return p.run()
  }

  // Run multiple named commands in parallel
  // commands is a Map of name -> command
  static runNamed(commands) { runNamed(commands, false) }
  static runNamed(commands, showOutput) {
    var p = Pipeline.new().verbose(false)
    for (entry in commands) {
      p.task(entry.key, entry.value)
      if (showOutput) {
        p.onSuccess(entry.key, Fn.new { |r|
          var out = r.stdout.trim()
          if (out != "") System.print("[%(r.name)] %(out)")
        })
        p.onFail(entry.key, Fn.new { |r|
          var err = r.stderr.trim()
          if (err != "") System.print("[%(r.name)] %(err)")
        })
      }
    }
    return p.run()
  }
}

// Convenience for sequential execution
class Sequential {
  // Run commands one after another
  // Set showOutput to true to print stdout/stderr from each task
  static run(commands) { run(commands, false) }
  static run(commands, showOutput) {
    var p = Pipeline.new().verbose(false)
    var prev = null
    var i = 0
    for (cmd in commands) {
      var name = "task_%(i)"
      if (prev == null) {
        p.task(name, cmd)
      } else {
        p.after(prev, name, cmd)
      }
      if (showOutput) {
        p.onSuccess(name, Fn.new { |r|
          var out = r.stdout.trim()
          if (out != "") System.print(out)
        })
        p.onFail(name, Fn.new { |r|
          var err = r.stderr.trim()
          if (err != "") System.print(err)
        })
      }
      prev = name
      i = i + 1
    }
    return p.run()
  }
}
