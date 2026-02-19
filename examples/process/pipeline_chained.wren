import "wrun/pipeline" for Pipeline
import "wrun/file" for File
import "wrun/print" for Log

Log.info("Testing chained method calls")

Pipeline.new()
  .task("github", "sleep 2 && echo 'GitHub done'")
  .task("readme", "sleep 4 && echo 'README content'")
  .after("github", "vercel", "sleep 1 && echo 'Vercel deployed'")
  .after("vercel", "domain", "sleep 1 && echo 'Domain set'")
  .onSuccess("readme", Fn.new { |r| File.write("README_TEST.md", r.stdout) })
  .finally("echo 'Final push!'")
  .finallyMode("success")
  .run()

Log.info("Done!")
