import "wrun/pipeline" for Pipeline
import "wrun/process" for Process
import "wrun/file" for File
import "wrun/args" for Args
import "wrun/print" for Log

// Parse arguments for --gen-readme flag and optional repo name
var genReadme = false
var repoName = null

for (i in 0...Args.count()) {
  var arg = Args.get(i)
  if (arg == "--gen-readme") {
    genReadme = true
  } else if (!arg.startsWith("--")) {
    repoName = arg
  }
}

if (repoName == null) {
  repoName = Process.cwd().split("/")[-1]
}

var domain = "%(repoName).stardive.live"

Log.addLevel("deploy", "blue")
Log.addLevel("readme", "magenta")

// Validate git repository
if (!File.isDirectory(".git")) {
  Log.error("Not a git repository.")
  Process.exit(1)
}

Log.info("Starting deployment pipeline (SIM)", {"project": repoName, "genReadme": genReadme})

var p = Pipeline.new()

// GitHub repo creation (always runs) - SIMULATED
p.task("github", "sleep 2 && echo 'GitHub repo created: %(repoName)'")

// README generation only runs with --gen-readme flag - SIMULATED
if (genReadme) {
  p.task("readme", "sleep 4 && echo '# %(repoName)\n\nGenerated README content here.'")

  // Handle README output - write to file
  p.onSuccess("readme", Fn.new { |result|
    if (result.stdout != "") {
      Log.custom("readme", "Writing README_TEST.md (sim)")
      if (File.write("README_TEST.md", result.stdout)) {
        Log.custom("readme", "README_TEST.md created successfully (sim)")
      } else {
        Log.warn("Failed to write README_TEST.md")
      }
    }
  })
}

// Vercel deployment runs after GitHub completes - SIMULATED
p.after("github", "vercel", "sleep 2 && echo 'Vercel deployed to production'")

// Domain assignment runs after Vercel succeeds - SIMULATED
p.after("vercel", "domain", "sleep 1 && echo 'Domain assigned: %(domain)'")

// GitHub may fail if repo already exists - that's ok
p.configure("github").failureMode("continue")

// Domain assignment is optional
p.configure("domain").failureMode("continue")

// Git push at the end, only if everything succeeded - SIMULATED
p.finally("echo 'git push (simulated)'")
p.finallyMode("success")

var result = p.run()

if (result.success) {
  Log.custom("deploy", "Project live at https://%(domain) (SIM)")
  Log.info("Deployment completed successfully (simulation)!")
} else {
  if (result.aborted) {
    Log.error("Deployment aborted due to failure")
    Process.exit(1)
  } else {
    Log.warn("Deployment completed with some non-critical failures")
  }
}
