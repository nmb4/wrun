import "wrun/pipeline" for Pipeline
import "wrun/process" for Process
import "wrun/file" for File
import "wrun/env" for Env
import "wrun/args" for Args
import "wrun/print" for Log

var runPull = false
var positionals = []

for (i in 0...Args.count()) {
  var arg = Args.get(i)
  if (arg == "--pull") {
    runPull = true
  } else {
    positionals.add(arg)
  }
}

// Remote host alias from ~/.ssh/config. Default: mini
var remoteHost = positionals.count > 0 ? positionals[0] : "mini"
// Path on remote host where prompt-studio lives.
var remoteProjectDir = positionals.count > 1 ? positionals[1] : "~/dev/prompt-studio"
// Source binary name produced by cargo build --release.
var sourceBinary = positionals.count > 2 ? positionals[2] : "prompt-studio"

var targetBinary = "allele"
var localInstallDir = "%(Env.home())/.cargo/bin"
var localBinaryPath = "%(localInstallDir)/%(targetBinary)"
var remoteReleaseDir = "%(remoteProjectDir)/target/release"

if (!File.isDirectory(localInstallDir)) {
  if (!File.mkdir(localInstallDir)) {
    Log.error("Could not create local install dir", {"path": localInstallDir})
    Process.exit(1)
  }
}

Log.addLevel("deploy", "blue")
Log.info("Starting remote release build + local install", {
  "host": remoteHost,
  "remoteDir": remoteProjectDir,
  "pull": runPull,
  "sourceBinary": sourceBinary,
  "targetBinary": targetBinary,
  "localPath": localBinaryPath
})

var p = Pipeline.new()

if (runPull) {
  p.task("pull", "ssh %(remoteHost) \"cd %(remoteProjectDir) && git pull\"")
  p.after("pull", "build", "ssh %(remoteHost) \"cd %(remoteProjectDir) && cargo build --release\"")
} else {
  p.task("build", "ssh %(remoteHost) \"cd %(remoteProjectDir) && cargo build --release\"")
}
p.buildStep("build", "prompt-studio-release")

p.after("build", "rename", "ssh %(remoteHost) \"cd %(remoteReleaseDir) && mv -f %(sourceBinary) %(targetBinary)\"")
p.after("rename", "copy", "scp %(remoteHost):%(remoteReleaseDir)/%(targetBinary) %(localBinaryPath)")
p.after("copy", "chmod", "chmod +x %(localBinaryPath)")

if (runPull) {
  p.failureMode("pull", "stop")
}
p.failureMode("build", "stop")
p.failureMode("rename", "stop")
p.failureMode("copy", "stop")
p.failureMode("chmod", "stop")

if (runPull) {
  p.onSuccess("pull", Fn.new { |result|
    Log.custom("deploy", "Remote git pull finished")
  })

  p.onFail("pull", Fn.new { |result|
    Log.error("Remote git pull failed", {"exitCode": result.exitCode, "stderr": result.stderr})
  })
}

p.onSuccess("build", Fn.new { |result|
  Log.custom("deploy", "Remote release build finished")
})

p.onSuccess("rename", Fn.new { |result|
  Log.custom("deploy", "Remote binary renamed to %(targetBinary)")
})

p.onSuccess("copy", Fn.new { |result|
  Log.custom("deploy", "Copied %(targetBinary) to %(localInstallDir)")
})

p.onFail("build", Fn.new { |result|
  Log.error("Remote build failed", {"exitCode": result.exitCode, "stderr": result.stderr})
})

p.onFail("rename", Fn.new { |result|
  Log.error("Remote rename failed", {"exitCode": result.exitCode, "stderr": result.stderr})
})

p.onFail("copy", Fn.new { |result|
  Log.error("Copy to local machine failed", {"exitCode": result.exitCode, "stderr": result.stderr})
})

p.onFail("chmod", Fn.new { |result|
  Log.error("chmod failed", {"exitCode": result.exitCode, "stderr": result.stderr})
})

var result = p.run()

if (result.success) {
  Log.custom("deploy", "Installed %(targetBinary) at %(localBinaryPath)")
  Log.info("Done")
} else {
  if (result.aborted) {
    Log.error("Aborted due to task failure")
  } else {
    Log.error("Pipeline finished with failures")
  }
  Process.exit(1)
}
