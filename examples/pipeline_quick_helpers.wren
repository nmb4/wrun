// Example: Using Parallel and Sequential helpers for simple cases
import "wrun/pipeline" for Parallel, Sequential
import "wrun/print" for Log

Log.info("=== Parallel execution ===")
var parallelResult = Parallel.run([
  "sleep 1 && echo 'Task A'",
  "sleep 1.5 && echo 'Task B'",
  "sleep 0.5 && echo 'Task C'"
])
Log.info("Parallel done, success: %(parallelResult.success)")

Log.info("")
Log.info("=== Sequential execution ===")
var seqResult = Sequential.run([
  "echo 'Step 1: Install' && sleep 1",
  "echo 'Step 2: Build' && sleep 1",
  "echo 'Step 3: Deploy' && sleep 1"
])
Log.info("Sequential done, success: %(seqResult.success)")
