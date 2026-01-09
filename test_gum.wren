import "wrun/process" for Shell

System.print("=== Testing interactive shell command ===")
System.print("")
System.print("Running 'gum confirm' interactively...")
System.print("")

var code = Shell.interactive("gum confirm")

System.print("")
System.print("Exit code: %(code)")
System.print("Success: %(Shell.success)")
