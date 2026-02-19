// Example: Different failure handling modes
import "wrun/pipeline" for Pipeline
import "wrun/print" for Log

Log.info("Testing failure modes")

var p = Pipeline.new()

// This task will fail (exit 1)
p.task("failing", "sleep 1 && echo 'About to fail' && exit 1")

// This runs in parallel and succeeds
p.task("passing", "sleep 2 && echo 'I passed!'")

// This depends on failing task - won't run if we use "stop" mode
p.after("failing", "dependent", "echo 'This depends on failing task'")

// Set failure mode: "continue" keeps going, "stop" aborts, "ignore" treats as success
p.failureMode("failing", "continue")

// Finally with "always" runs even if something failed
p.finally("echo 'Cleanup always runs'")
p.finallyMode("always")

var result = p.run()

Log.info("Pipeline success: %(result.success)")
Log.info("Failing task succeeded: %(result.succeeded("failing"))")
Log.info("Passing task succeeded: %(result.succeeded("passing"))")
