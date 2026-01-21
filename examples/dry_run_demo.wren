import "wrun/process" for Shell, Process

System.print("=== wrun dry-run demo ===")
System.print("")

System.print("Listing files with 'ls':")
Shell.run("ls -la | head -5")
System.print("  stdout: %(Shell.stdout)")

System.print("")
System.print("Echo a message:")
Shell.run("echo 'Hello from wrun dry-run!'")
System.print("  stdout: %(Shell.stdout)")

System.print("")
System.print("Get current directory:")
Shell.run("pwd")
System.print("  stdout: %(Shell.stdout)")

System.print("")
System.print("Check system info:")
Shell.run("uname -s -m")
System.print("  stdout: %(Shell.stdout)")

System.print("")
System.print("=== Done! ===")