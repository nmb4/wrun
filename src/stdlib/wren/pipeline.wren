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

import "wrun/process" for Shell
import "wrun/print" for Log

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
    _logLevel = "info"      // Log level for this task
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

  // Start a task
  startTask_(task) {
    task.started = true
    task.handle = Shell.spawnAsync(task.command)
    if (task.handle == 0) {
      // Failed to spawn
      task.done = true
      task.result = TaskResult.new(task.name, -1, "", "Failed to spawn process")
      if (_verbose) Log.error("Failed to start: %(task.name)")
    } else {
      if (_verbose) Log.custom(task.logLevel, "Started: %(task.name)")
    }
  }

  // Complete a task
  completeTask_(task) {
    task.done = true
    var code = Shell.getExitCode(task.handle)
    var stdout = Shell.getStdout(task.handle)
    var stderr = Shell.getStderr(task.handle)
    Shell.cleanup(task.handle)
    
    task.result = TaskResult.new(task.name, code, stdout, stderr)
    _results[task.name] = task.result
    
    if (task.success) {
      if (_verbose) Log.custom(task.logLevel, "Completed: %(task.name)")
    } else {
      if (_verbose) Log.warn("Failed: %(task.name) (exit code %(code))")
    }
    
    task.invokeCallbacks()
  }

  // Main execution loop
  run() {
    if (_verbose) Log.info("Pipeline starting with %(this.taskCount) tasks")

    // Main event loop
    while (!allDone_() && !_aborted) {
      // Check for abort condition
      if (shouldAbort_()) {
        _aborted = true
        if (_verbose) Log.error("Pipeline aborted due to task failure")
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
        if (_verbose) Log.info("Running finally: %(_finally)")
        var code = Shell.exec(_finally)
        if (code == 0) {
          if (_verbose) Log.info("Finally completed successfully")
        } else {
          if (_verbose) Log.warn("Finally failed with code %(code)")
        }
      }
    }

    if (_verbose) {
      if (_aborted) {
        Log.error("Pipeline aborted")
      } else if (allSucceeded_()) {
        Log.info("Pipeline completed successfully")
      } else {
        Log.warn("Pipeline completed with failures")
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
  static run(commands) {
    var p = Pipeline.new().verbose(false)
    var i = 0
    for (cmd in commands) {
      p.task("task_%(i)", cmd)
      i = i + 1
    }
    return p.run()
  }

  // Run multiple named commands in parallel
  // commands is a Map of name -> command
  static runNamed(commands) {
    var p = Pipeline.new().verbose(false)
    for (entry in commands) {
      p.task(entry.key, entry.value)
    }
    return p.run()
  }
}

// Convenience for sequential execution
class Sequential {
  // Run commands one after another
  static run(commands) {
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
      prev = name
      i = i + 1
    }
    return p.run()
  }
}
