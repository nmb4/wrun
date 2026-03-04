import "wrun/process" for Shell, Process
import "wrun/print" for Print, Log
import "wrun/str" for Str
import "wrun/file" for File, Path, Dir
import "wrun/env" for Env
import "wrun/args" for Args

// 1. List of models to benchmark
var models = [
  "qwen3.5-9b",
  "qwen3.5-2b",
  // Add more models here...
]

// 2. Host Options
var hostOptions = ["localhost", "minimac.local"]
var host = hostOptions[0]

// Optional: Pass the host as the first argument, e.g., `wrun lms_benchmark.wren minimac.local`
if (Args.count() > 0) {
  var argHost = Args.first()
  if (hostOptions.contains(argHost)) {
    host = argHost
  } else {
    Log.warn("Unknown host '%(argHost)', defaulting to %(host)")
  }
}

Log.info("Starting LM Studio Benchmark", {"host": host})

// Helper to run `lms` commands locally or via SSH
var runLmsCommand = Fn.new { |cmd|
  var fullCmd = "lms %(cmd)"
  if (host != "localhost") {
    fullCmd = "ssh %(host) \"%(fullCmd)\""
  }
  Shell.run(fullCmd)
  return [Shell.success, Shell.stdout, Shell.stderr]
}

var stats = []
var prompt = "Explain the history of quantum mechanics in 500 words."

for (model in models) {
  System.print("\n==================================================")
  Log.info("Benchmarking model", {"model": model})
  
  // Unload all models to free memory before loading the next one
  Log.info("Unloading all models to clear memory...")
  runLmsCommand.call("unload --all")
  Process.sleep(2) // Wait a moment for resources to be freed
  
  // Load the specific model
  Log.info("Loading model...")
  var loadRes = runLmsCommand.call("load %(model)")
  if (!loadRes[0]) {
    Log.error("Failed to load model", {"error": loadRes[2]})
    stats.add({"model": model, "status": "Failed to load", "tps": "-", "memory": "-"})
    continue // Flexible error handling: continue to the next model
  }
  
  // Get Memory Consumption
  Log.info("Checking memory consumption...")
  var memory = "Unknown"
  var psRegular = runLmsCommand.call("ps")
  if (psRegular[0]) {
    var lines = Str.lines(psRegular[1])
    for (line in lines) {
      if (Str.contains(line, model)) {
        // 'lms ps' typically outputs: [model name]  [size]  [RAM]
        // Extract the line containing the model as a proxy for memory/status
        memory = Str.trim(line)
        break
      }
    }
  }
  
  // Run inference to calculate TPS
  Log.info("Running inference...")
  
  var payload = "{\"model\": \"%(model)\", \"system_prompt\": \"You are a helpful assistant.\", \"input\": \"%(prompt)\"}"
  
  var curlCmd = "curl -s -X POST http://%(host):1234/api/v1/chat " + 
                "-H \"Content-Type: application/json\" " + 
                "-d \"%(payload)\""
                
  Shell.run(curlCmd)
  
  if (!Shell.success) {
    Log.error("API call failed", {"error": Shell.stderr})
    stats.add({"model": model, "status": "API Error", "tps": "-", "memory": memory})
    continue
  }
  
  var responseJson = Shell.stdout
  var tps = 0
  var tokens = 0
  
  // Parse tokens_per_second out of the JSON response
  var tpsIdx = Str.indexOf(responseJson, "\"tokens_per_second\":")
  if (tpsIdx != -1) {
    var sub = Str.slice(responseJson, tpsIdx + 20)
    var commaIdx = Str.indexOf(sub, ",")
    var braceIdx = Str.indexOf(sub, "}")
    var endIdx = commaIdx
    if (endIdx == -1 || (braceIdx != -1 && braceIdx < endIdx)) {
      endIdx = braceIdx
    }
    if (endIdx != -1) {
      var tpsStr = Str.trim(Str.sliceRange(sub, 0, endIdx))
      var parsed = Num.fromString(tpsStr)
      if (parsed != null) tps = parsed
    }
  }

  // Parse total_output_tokens
  var tokenIdx = Str.indexOf(responseJson, "\"total_output_tokens\":")
  if (tokenIdx != -1) {
    var sub = Str.slice(responseJson, tokenIdx + 22)
    var commaIdx = Str.indexOf(sub, ",")
    var braceIdx = Str.indexOf(sub, "}")
    var endIdx = commaIdx
    if (endIdx == -1 || (braceIdx != -1 && braceIdx < endIdx)) {
      endIdx = braceIdx
    }
    if (endIdx != -1) {
      var tokenStr = Str.trim(Str.sliceRange(sub, 0, endIdx))
      var parsed = Num.fromString(tokenStr)
      if (parsed != null) tokens = parsed
    }
  }
  
  Log.info("Inference complete", {"tokens": tokens, "tps": tps})
  
  if (tokens == 0) {
    stats.add({"model": model, "status": "0 tokens returned", "tps": "-", "memory": memory})
  } else {
    stats.add({"model": model, "status": "Success", "tps": tps, "memory": memory})
  }
}

System.print("\n==================================================")
Log.info("Unloading models to clean up...")
runLmsCommand.call("unload --all")

// Generate Markdown Table
var markdown = "# LM Studio Benchmark Results\n\n"
markdown = markdown + "**Host**: %(host)\n\n"
markdown = markdown + "| Model | Status | TPS | Memory / Process Info |\n"
markdown = markdown + "|-------|--------|-----|-----------------------|\n"

for (stat in stats) {
  var tpsStr = stat["tps"]
  if (stat["tps"] is Num) {
    // Round to 2 decimal places
    var rounded = (stat["tps"] * 100).round / 100
    tpsStr = "%(rounded)"
  }
  
  var mem = stat["memory"]
  // Clean up any pipes from lms output that could break markdown table formatting
  mem = Str.replaceAll(mem, "|", "-")
  
  if (Str.length(mem) > 60) {
     mem = Str.slice(mem, 0, 57) + "..."
  }
  var m = stat["model"]
  var s = stat["status"]
  markdown = markdown + "| %(m) | %(s) | %(tpsStr) | %(mem) |\n"
}

System.print("\n" + markdown)

// Write to file with date and time
var dateFormat = "%%Y-%%m-%%d_%%H-%%M-%%S"
Shell.run("date +'" + dateFormat + "'")
var dateStr = "unknown_date"
if (Shell.success) {
  dateStr = Str.trim(Shell.stdout)
}

var filename = "benchmark_" + dateStr + ".md"
File.write(filename, markdown)
Log.info("Benchmark complete", {"file": filename})
