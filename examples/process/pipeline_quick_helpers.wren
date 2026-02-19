// Example: Using Parallel and Sequential helpers for simple cases
import "wrun/pipeline" for Parallel, Sequential
import "wrun/print" for Log

Log.setTerminalLevel("trace")

Log.info("=== Parallel execution (with output) ===")
var parallelResult = Parallel.run([
  "sleep 1 && echo 'Task A done'",
  "sleep 1.5 && echo 'Task B done'",
  "sleep 0.5 && echo 'Task C done'"
], true)
Log.info("Parallel done, success: %(parallelResult.success)")

Log.info("")
Log.info("=== Sequential execution (with output) ===")
var seqResult = Sequential.run([
  "echo 'Step 1: Install'",
  "echo 'Step 2: Build'",
  "echo 'Step 3: Deploy'"
], true)
Log.info("Sequential done, success: %(seqResult.success)")

Log.info("")
Log.info("=== Without output (quiet mode) ===")
Parallel.run([
  "echo 'You wont see this'",
  "echo 'Or this'"
])
Log.info("Quiet mode done")
