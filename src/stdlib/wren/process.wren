foreign class Process {
    construct new() {}
    foreign static cwd()
    foreign static chdir(path)
    foreign static exit(code)
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
}
