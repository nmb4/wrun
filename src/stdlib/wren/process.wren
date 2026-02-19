foreign class Process {
    construct new() {}
    foreign static cwd()
    foreign static chdir(path)
    foreign static exit(code)
    foreign static sleep(seconds)
}

foreign class Shell {
    construct new() {}
    foreign static run(command)
    foreign static stdout
    foreign static stderr
    foreign static exitCode
    foreign static success
    foreign static exec(command)
    foreign static interactive(command)
    foreign static spawn(command)
    
    // Async process management
    foreign static spawnAsync(command)  // Returns handle (0 on failure)
    foreign static isDone(handle)       // Non-blocking check if process finished
    foreign static wait(handle)         // Blocking wait, returns exit code
    foreign static getStdout(handle)    // Get stdout after completion
    foreign static getStderr(handle)    // Get stderr after completion
    foreign static getExitCode(handle)  // Get exit code after completion
    foreign static cleanup(handle)      // Remove handle from tracking
}
