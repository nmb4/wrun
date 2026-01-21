import "wrun/pipeline" for Pipeline
import "wrun/process" for Process
import "wrun/file" for File
import "wrun/args" for Args
import "wrun/print" for Log

var repoName = Args.count() > 0 ? Args.get(0) : Process.cwd().split("/")[-1]
var domain = "%(repoName).stardive.live"

Log.addLevel("deploy", "blue")
Log.addLevel("readme", "magenta")

var p = Pipeline.new()

// GitHub and README run in parallel (no dependencies)
p.task("github", "sleep 3 && echo 'GitHub done'")
p.task("readme", "sleep 6 && echo 'README content here'")

// Vercel runs after GitHub completes
p.after("github", "vercel", "sleep 2 && echo 'Vercel deployed'")

// Domain runs after Vercel
p.after("vercel", "domain", "sleep 1 && echo 'Domain assigned'")

// Handle README output
p.onSuccess("readme", Fn.new { |result|
  Log.custom("readme", "Writing README.md")
  File.write("README_TEST.md", result.stdout)
})

// Git push runs at the end, only if everything succeeded
p.finally("echo 'git push' && sleep 1")
p.finallyMode("success")

p.run()

Log.info("All done!")
