import "wrun/print" for Log
Log.setTerminalLevel("trace")
Log.info("Starting up")
Log.warn("Something fishy")
Log.error("Failed!")
Log.debug("Debug info", {"key": "value"})
Log.trace("Trace message")
