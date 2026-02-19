// Example: Mark a task as a build step with persisted timing history + ETA.
import "wrun/pipeline" for Pipeline
import "wrun/print" for Log

Log.info("Build step ETA demo (run this twice to see ETA from history)")

var p = Pipeline.new()
  .pollInterval(0.1)
  .timingsDir(".wrun_pipeline_timings")

p.task("prepare", "sleep 0.5 && echo 'prepare done'")
p.after("prepare", "build", "sleep 4 && echo 'build done'")

// Persist timing under this key and show live elapsed/ETA logs while running.
p.buildStep("build", "demo-build")
p.failureMode("build", "stop")

var result = p.run()
Log.info("Pipeline success: %(result.success)")
