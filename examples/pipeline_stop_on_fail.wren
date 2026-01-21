// Example: Stop entire pipeline when critical task fails
import "wrun/pipeline" for Pipeline
import "wrun/print" for Log

Log.info("Testing 'stop' failure mode - pipeline aborts on failure")

var p = Pipeline.new()

p.task("setup", "echo 'Setting up...' && sleep 1")
p.after("setup", "critical", "echo 'Critical check...' && sleep 1 && exit 1")
p.after("critical", "build", "echo 'Building...' && sleep 1")
p.after("build", "deploy", "echo 'Deploying...' && sleep 1")

// Mark critical task to stop pipeline on failure
p.failureMode("critical", "stop")

// Finally only runs on failure since we expect abort
p.finally("echo 'Emergency cleanup!'")
p.finallyMode("failure")

var result = p.run()

Log.info("Aborted: %(result.aborted)")
Log.info("Build ran: %(result.succeeded("build"))")
