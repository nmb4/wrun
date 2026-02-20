foreign class PrintInternal {
    construct new() {}
    foreign static eprint(msg)
    foreign static cprint(msg)
    foreign static cprintColor(msg, color)
    foreign static live(msg)
    foreign static liveColor(msg, color)
    foreign static liveDone()
}

class Print {
    static eprint(msg) { PrintInternal.eprint(msg) }
    static cprint(msg) { PrintInternal.cprint(msg) }
    static cprint(msg, color) { PrintInternal.cprintColor(msg, color) }
    static live(msg) { PrintInternal.live(msg) }
    static live(msg, color) { PrintInternal.liveColor(msg, color) }
    static liveDone() { PrintInternal.liveDone() }
}

foreign class LogInternal {
    construct new() {}

    // Level methods without kv
    foreign static trace(msg)
    foreign static traceKv(msg, kv)
    foreign static debug(msg)
    foreign static debugKv(msg, kv)
    foreign static info(msg)
    foreign static infoKv(msg, kv)
    foreign static warn(msg)
    foreign static warnKv(msg, kv)
    foreign static error(msg)
    foreign static errorKv(msg, kv)
    foreign static custom(level, msg)
    foreign static customKv(level, msg, kv)
    foreign static live(level, msg)
    foreign static liveKv(level, msg, kv)
    foreign static liveColor(level, msg, color)
    foreign static liveColorKv(level, msg, kv, color)

    // Configuration
    foreign static setFile(path)
    foreign static setTerminalLevel(level)
    foreign static setFileLevel(level)
    foreign static addLevel(name, color, baseLevel)
}

// Wrapper class that handles Map serialization for structured logging
class Log {
    static trace(msg) { LogInternal.trace(msg) }
    static trace(msg, kv) { LogInternal.traceKv(msg, Log.serializeKv_(kv)) }

    static debug(msg) { LogInternal.debug(msg) }
    static debug(msg, kv) { LogInternal.debugKv(msg, Log.serializeKv_(kv)) }

    static info(msg) { LogInternal.info(msg) }
    static info(msg, kv) { LogInternal.infoKv(msg, Log.serializeKv_(kv)) }

    static warn(msg) { LogInternal.warn(msg) }
    static warn(msg, kv) { LogInternal.warnKv(msg, Log.serializeKv_(kv)) }

    static error(msg) { LogInternal.error(msg) }
    static error(msg, kv) { LogInternal.errorKv(msg, Log.serializeKv_(kv)) }

    static custom(level, msg) { LogInternal.custom(level, msg) }
    static custom(level, msg, kv) { LogInternal.customKv(level, msg, Log.serializeKv_(kv)) }
    static live(level, msg) { LogInternal.live(level, msg) }
    static live(level, msg, kv) { LogInternal.liveKv(level, msg, Log.serializeKv_(kv)) }
    static liveColor(level, msg, color) { LogInternal.liveColor(level, msg, color) }
    static liveColor(level, msg, kv, color) { LogInternal.liveColorKv(level, msg, Log.serializeKv_(kv), color) }

    // Configuration
    static setFile(path) { LogInternal.setFile(path) }
    static setTerminalLevel(level) { LogInternal.setTerminalLevel(level) }
    static setFileLevel(level) { LogInternal.setFileLevel(level) }
    static addLevel(name) { LogInternal.addLevel(name, "", "") }
    static addLevel(name, color) { LogInternal.addLevel(name, color, "") }
    static addLevel(name, color, baseLevel) { LogInternal.addLevel(name, color, baseLevel) }

    // Serialize a Map to "key=value\0key=value" format
    static serializeKv_(kv) {
        if (kv == null) return ""
        if (!(kv is Map)) return ""

        var parts = []
        for (entry in kv) {
            parts.add("%(entry.key)=%(entry.value)")
        }
        return parts.join("\x00")
    }
}
