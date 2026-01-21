import "wrun/process" for Shell, Process
import "wrun/file" for File
import "wrun/args" for Args
import "wrun/print" for Log

class Publisher {
  static run() {
    Log.addLevel("deploy", "blue")
    Log.addLevel("readme", "magenta")

    if (!File.isDirectory(".git")) {
      Log.error("Not a git repository.")
      Process.exit(1)
    }

    var repoName = Args.count() > 0 ? Args.get(0) : Process.cwd().split("/")[-1]
    var domain = "%(repoName).stardive.live"

    Log.info("Starting parallel deployment", {"project": repoName})

    // Spawn both tasks in parallel using async processes
    var readmeHandle = Shell.spawnAsync("sleep 20 && echo CLAUDE RESPONSE")

    var ghHandle = Shell.spawnAsync("sleep 3 && exit 1")

    if (readmeHandle == 0) {
      Log.warn("Failed to spawn README generation")
    } else {
      Log.info("README generation started (async)")
    }

    if (ghHandle == 0) {
      Log.warn("Failed to spawn GitHub creation")
    } else {
      Log.info("GitHub repo creation started (async)")
    }

    // Track state
    var readmeDone = readmeHandle == 0
    var ghDone = ghHandle == 0
    var vercelStarted = false
    var vercelHandle = 0
    var vercelDone = false
    var domainDone = false

    // Main event loop - run until everything is done
    while (!readmeDone || !vercelDone || !domainDone) {
      // Check README generation
      if (!readmeDone && Shell.isDone(readmeHandle)) {
        readmeDone = true
        var code = Shell.getExitCode(readmeHandle)
        if (code == 0) {
          var content = Shell.getStdout(readmeHandle)
          if (content != "" && File.write("README_TEST.md", content)) {
            Log.custom("readme", "README.md written successfully")
            Shell.exec("sleep 1")
          }
        } else {
          Log.warn("README generation failed", {"stderr": Shell.getStderr(readmeHandle)})
        }
        Shell.cleanup(readmeHandle)
      }

      // Check GitHub creation
      if (!ghDone && Shell.isDone(ghHandle)) {
        ghDone = true
        var code = Shell.getExitCode(ghHandle)
        if (code == 0) {
          Log.custom("deploy", "GitHub repository created and pushed")
        } else {
          Log.warn("GitHub step encountered an issue (repo might already exist)")
        }
        Shell.cleanup(ghHandle)
      }

      // Start Vercel as soon as GitHub is done
      if (ghDone && !vercelStarted) {
        vercelStarted = true
        Log.info("Deploying to Vercel")
        vercelHandle = Shell.spawnAsync("sleep 2")
        if (vercelHandle == 0) {
          Log.error("Failed to spawn Vercel deployment")
          vercelDone = true
          domainDone = true
        }
      }

      // Check Vercel deployment
      if (vercelStarted && !vercelDone && vercelHandle != 0 && Shell.isDone(vercelHandle)) {
        vercelDone = true
        var code = Shell.getExitCode(vercelHandle)
        Shell.cleanup(vercelHandle)
        if (code != 0) {
          Log.error("Vercel deployment failed")
          domainDone = true
        } else {
          Log.custom("deploy", "Vercel deployment successful")
          // Start domain assignment
          Log.info("Assigning domain", {"domain": domain})
          var domainStatus = Shell.exec("sleep 5")
          domainDone = true
          if (domainStatus == 0) {
            Log.custom("deploy", "Project live at https://%(domain)")
          } else {
            Log.warn("Deployment succeeded, but domain assignment failed")
          }
        }
      }

      // Small sleep to avoid busy-waiting
      if (!readmeDone || !vercelDone) {
        Shell.exec("sleep 0.1")
      }
    }

    // Push README commit if it was created
    Shell.exec("sleep 1")
    Log.info("Done!")
  }
}

Publisher.run()
