// Example: Using callbacks to process task output
import "wrun/pipeline" for Pipeline
import "wrun/file" for File
import "wrun/print" for Log

Log.info("Pipeline with callbacks")

var p = Pipeline.new()

p.task("fetch_data", "sleep 1 && echo '{\"users\": 42, \"active\": true}'")
p.task("generate_report", "sleep 2 && echo '# Monthly Report\n\nEverything is fine.'")

p.onSuccess("fetch_data", Fn.new { |result|
  Log.info("Got data: %(result.stdout.trim())")
  File.write("data.json", result.stdout)
})

p.onSuccess("generate_report", Fn.new { |result|
  Log.info("Report generated, saving...")
  File.write("report.md", result.stdout)
})

p.onFail("fetch_data", Fn.new { |result|
  Log.error("Failed to fetch: %(result.stderr)")
})

p.after("fetch_data", "process", "sleep 0.5 && echo 'Processing complete'")

p.run()

// Cleanup test files
File.delete("data.json")
File.delete("report.md")
