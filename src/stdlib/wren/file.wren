import "wrun/process" for Process
import "wrun/str" for Str

foreign class File {
    construct new() {}
    foreign static read(path)
    foreign static readBytes(path)
    foreign static write(path, content)
    foreign static writeBytes(path, bytes)
    foreign static append(path, content)
    foreign static exists(path)
    foreign static isFile(path)
    foreign static isDirectory(path)
    foreign static delete(path)
    foreign static copy(from, to)
    foreign static rename(from, to)
    foreign static mkdir(path)
    foreign static size(path)
    foreign static modified(path)
}

foreign class Dir {
    construct new() {}
    foreign static list(path)
    foreign static create(path)
    foreign static remove(path)
    foreign static exists(path)
}

foreign class PathUtil {
    construct new() {}
    foreign static join(a, b)
    foreign static dirname(path)
    foreign static basename(path)
    foreign static extension(path)
    foreign static absolute(path)
    foreign static isAbsolute(path)
}

foreign class NativeWatch {
    construct new() {}
    foreign static watch(path, recursive)
    foreign static has(handle)
    foreign static close(handle)
    foreign static closeAll()
    foreign static pending(handle)
    foreign static takeEvent(handle)
    foreign static waitEvent(handle, timeoutSeconds)
}

foreign class DiffUtil {
    construct new() {}
    foreign static pretty(path, before, after, granularity, algorithm)
    foreign static patch(path, before, after)
    foreign static patchColor(path, before, after)
    foreign static applyPatchResult(base, patchText)
}

class Path {
    static join(a, b) { PathUtil.join(a, b) }
    static dirname(path) { PathUtil.dirname(path) }
    static basename(path) { PathUtil.basename(path) }
    static extension(path) { PathUtil.extension(path) }
    static absolute(path) { PathUtil.absolute(path) }
    static isAbsolute(path) { PathUtil.isAbsolute(path) }
}

class Diff {
    static granularity_(granularity) {
        if (granularity == "word") return "word"
        if (granularity == "char") return "char"
        return "line"
    }

    static algorithm_(algorithm) {
        if (algorithm == "patience") return "patience"
        if (algorithm == "lcs") return "lcs"
        return "myers"
    }

    static pretty(path, before, after) {
        return DiffUtil.pretty(path, before, after, "line", "myers")
    }

    static pretty(path, before, after, granularity) {
        return DiffUtil.pretty(path, before, after, granularity_(granularity), "myers")
    }

    static pretty(path, before, after, granularity, algorithm) {
        return DiffUtil.pretty(path, before, after, granularity_(granularity), algorithm_(algorithm))
    }

    static patch(path, before, after) {
        return DiffUtil.patch(path, before, after)
    }

    static patchColor(path, before, after) {
        return DiffUtil.patchColor(path, before, after)
    }

    static applyPatchResult(base, patchText) {
        return DiffUtil.applyPatchResult(base, patchText)
    }

    static applyPatch(base, patchText) {
        var result = applyPatchResult(base, patchText)
        if (result.count < 2) return null
        if (result[0] != "ok") return null
        return result[1]
    }
}

class FileWatcher {
    construct new(path) {
        _root = Path.absolute(path)
        _recursive = true
        _pollInterval = 0.25
        _diffGranularity = "line"
        _diffAlgorithm = "myers"
        _includePrettyDiff = true
        _includePatch = true
        _listeners = []
        _running = false
        _snapshot = {}
        _contentCache = {}
        _lastEvents = []
    }

    static watch(path) {
        return FileWatcher.new(path).start()
    }

    static watch(path, handler) {
        return FileWatcher.new(path).onChange(handler).start()
    }

    root { _root }
    running { _running }
    lastEvents { _lastEvents }

    recursive(enabled) {
        _recursive = enabled
        return this
    }

    pollInterval(seconds) {
        if (seconds <= 0) return this
        _pollInterval = seconds
        return this
    }

    diffGranularity(granularity) {
        _diffGranularity = Diff.granularity_(granularity)
        return this
    }

    diffAlgorithm(algorithm) {
        _diffAlgorithm = Diff.algorithm_(algorithm)
        return this
    }

    includePrettyDiff(enabled) {
        _includePrettyDiff = enabled
        return this
    }

    includePatch(enabled) {
        _includePatch = enabled
        return this
    }

    onChange(handler) {
        if (handler != null) {
            _listeners.add(handler)
        }
        return this
    }

    clearHandlers() {
        _listeners.clear()
        return this
    }

    start() {
        _snapshot = snapshot_()
        _contentCache = buildContentCache_(_snapshot)
        _running = true
        return this
    }

    stop() {
        _running = false
        return this
    }

    step() {
        if (!_running) return []

        var nextSnapshot = snapshot_()
        var nextContentCache = {}
        var events = diffSnapshots_(_snapshot, nextSnapshot, _contentCache, nextContentCache)
        _snapshot = nextSnapshot
        _contentCache = nextContentCache
        _lastEvents = events
        dispatchEvents_(events)
        return events
    }

    run() {
        if (!_running) start()
        while (_running) {
            step()
            if (_running && _pollInterval > 0) {
                Process.sleep(_pollInterval)
            }
        }
        return this
    }

    snapshot_() {
        var snapshot = {}
        collectState_(_root, snapshot)
        return snapshot
    }

    collectState_(path, snapshot) {
        if (!File.exists(path)) return

        var state = stateFor_(path)
        snapshot[path] = state

        if (state["isDirectory"] && _recursive) {
            for (name in Dir.list(path)) {
                collectState_(Path.join(path, name), snapshot)
            }
        }
    }

    stateFor_(path) {
        var isDirectory = File.isDirectory(path)
        return {
            "path": path,
            "exists": true,
            "isDirectory": isDirectory,
            "size": isDirectory ? -1 : File.size(path),
            "modified": File.modified(path)
        }
    }

    buildContentCache_(snapshot) {
        var cache = {}
        for (entry in snapshot) {
            var path = entry.key
            var state = entry.value
            if (state["isDirectory"]) continue
            cache[path] = safeReadContent_(path)
        }
        return cache
    }

    safeReadContent_(path) {
        if (!File.exists(path) || File.isDirectory(path)) return null
        return File.read(path)
    }

    resolveNextContent_(path, after, previous, previousContentCache) {
        if (after["isDirectory"]) return null

        if (previous.containsKey(path)) {
            var before = previous[path]
            if (!stateChanged_(before, after) && previousContentCache.containsKey(path)) {
                return previousContentCache[path]
            }
        }

        return safeReadContent_(path)
    }

    diffSnapshots_(previous, current, previousContentCache, nextContentCache) {
        var events = []

        for (entry in current) {
            var path = entry.key
            var after = entry.value
            var afterContent = resolveNextContent_(path, after, previous, previousContentCache)
            if (afterContent != null) {
                nextContentCache[path] = afterContent
            }

            if (!previous.containsKey(path)) {
                events.add(eventContext_("created", path, null, after, null, afterContent))
                continue
            }

            var before = previous[path]
            var beforeContent = null
            if (previousContentCache.containsKey(path)) {
                beforeContent = previousContentCache[path]
            }

            if (stateChanged_(before, after) || beforeContent != afterContent) {
                events.add(eventContext_("modified", path, before, after, beforeContent, afterContent))
            }
        }

        for (entry in previous) {
            var path = entry.key
            if (!current.containsKey(path)) {
                var beforeContent = null
                if (previousContentCache.containsKey(path)) {
                    beforeContent = previousContentCache[path]
                }
                events.add(eventContext_("deleted", path, entry.value, null, beforeContent, null))
            }
        }

        return events
    }

    stateChanged_(before, after) {
        if (before["isDirectory"] != after["isDirectory"]) return true
        if (before["size"] != after["size"]) return true
        if (before["modified"] != after["modified"]) return true
        return false
    }

    contentDiffFor_(kind, isDirectory, beforeContent, afterContent) {
        if (isDirectory) return null

        var beforeText = beforeContent == null ? "" : beforeContent
        var afterText = afterContent == null ? "" : afterContent
        if (beforeText == afterText) return null

        var diff = lineDiff_(beforeText, afterText)
        diff["kind"] = kind
        return diff
    }

    linesForText_(text) {
        if (text == null || text == "") return []
        return Str.lines(text)
    }

    lineDiff_(beforeText, afterText) {
        var beforeLines = linesForText_(beforeText)
        var afterLines = linesForText_(afterText)

        var prefix = 0
        while (prefix < beforeLines.count && prefix < afterLines.count && beforeLines[prefix] == afterLines[prefix]) {
            prefix = prefix + 1
        }

        var beforeTail = beforeLines.count - 1
        var afterTail = afterLines.count - 1
        while (beforeTail >= prefix && afterTail >= prefix && beforeLines[beforeTail] == afterLines[afterTail]) {
            beforeTail = beforeTail - 1
            afterTail = afterTail - 1
        }

        var removed = []
        if (beforeTail >= prefix) {
            for (i in prefix..beforeTail) {
                removed.add(beforeLines[i])
            }
        }

        var added = []
        if (afterTail >= prefix) {
            for (i in prefix..afterTail) {
                added.add(afterLines[i])
            }
        }

        return {
            "algorithm": "line-prefix-suffix",
            "startLine": prefix + 1,
            "beforeLineCount": beforeLines.count,
            "afterLineCount": afterLines.count,
            "removed": removed,
            "removedCount": removed.count,
            "added": added,
            "addedCount": added.count
        }
    }

    eventContext_(kind, path, before, after, beforeContent, afterContent) {
        var isDirectory = false
        if (after != null) {
            isDirectory = after["isDirectory"]
        } else if (before != null) {
            isDirectory = before["isDirectory"]
        }
        var contentDiff = contentDiffFor_(kind, isDirectory, beforeContent, afterContent)
        var prettyDiff = null
        var patch = null
        var patchColor = null

        if (contentDiff != null) {
            var beforeText = beforeContent == null ? "" : beforeContent
            var afterText = afterContent == null ? "" : afterContent
            if (_includePrettyDiff) {
                prettyDiff = Diff.pretty(path, beforeText, afterText, _diffGranularity, _diffAlgorithm)
            }
            if (_includePatch) {
                patch = Diff.patch(path, beforeText, afterText)
                patchColor = Diff.patchColor(path, beforeText, afterText)
            }
        }

        return {
            "kind": kind,
            "root": _root,
            "path": path,
            "isDirectory": isDirectory,
            "timestamp": System.clock,
            "before": before,
            "after": after,
            "contentChanged": contentDiff != null,
            "contentDiff": contentDiff,
            "diffGranularity": _diffGranularity,
            "diffAlgorithm": _diffAlgorithm,
            "prettyDiff": prettyDiff,
            "patch": patch,
            "patchColor": patchColor
        }
    }

    dispatchEvents_(events) {
        if (_listeners.count == 0 || events.count == 0) return
        for (event in events) {
            for (handler in _listeners) {
                invokeHandler_(handler, event)
            }
        }
    }

    invokeHandler_(handler, event) {
        if (handler == null) return

        if (handler is Fiber) {
            if (!handler.isDone) {
                handler.call(event)
            }
            return
        }

        var fiber = Fiber.new { handler.call(event) }
        fiber.call()
    }
}

class NativeFileWatcher {
    construct new(path) {
        _root = Path.absolute(path)
        _recursive = true
        _runMode = "poll"
        _pollInterval = 0.10
        _waitTimeout = 0.50
        _fallbackPolling = true
        _diffGranularity = "line"
        _diffAlgorithm = "myers"
        _includePrettyDiff = true
        _includePatch = true
        _listeners = []
        _running = false
        _handle = 0
        _lastEvents = []
        _fallbackSnapshot = {}
        _fallbackContentCache = {}
        _nativeSnapshot = {}
        _nativeContentCache = {}
        _sawNativeEvent = false
    }

    static watch(path) {
        return NativeFileWatcher.new(path).start()
    }

    static watch(path, handler) {
        return NativeFileWatcher.new(path).onChange(handler).start()
    }

    root { _root }
    running { _running }
    lastEvents { _lastEvents }
    handle { _handle }
    sawNativeEvent { _sawNativeEvent }
    runMode { _runMode }

    recursive(enabled) {
        _recursive = enabled
        return this
    }

    pollInterval(seconds) {
        if (seconds <= 0) return this
        _pollInterval = seconds
        return this
    }

    waitTimeout(seconds) {
        if (seconds <= 0) return this
        _waitTimeout = seconds
        return this
    }

    mode(name) {
        if (name == "poll" || name == "wait") {
            _runMode = name
        }
        return this
    }

    blockingWait(enabled) {
        _runMode = enabled ? "wait" : "poll"
        return this
    }

    fallbackPolling(enabled) {
        _fallbackPolling = enabled
        return this
    }

    diffGranularity(granularity) {
        _diffGranularity = Diff.granularity_(granularity)
        return this
    }

    diffAlgorithm(algorithm) {
        _diffAlgorithm = Diff.algorithm_(algorithm)
        return this
    }

    includePrettyDiff(enabled) {
        _includePrettyDiff = enabled
        return this
    }

    includePatch(enabled) {
        _includePatch = enabled
        return this
    }

    onChange(handler) {
        if (handler != null) {
            _listeners.add(handler)
        }
        return this
    }

    clearHandlers() {
        _listeners.clear()
        return this
    }

    start() {
        if (_running && _handle != 0) return this
        _handle = NativeWatch.watch(_root, _recursive)
        _running = _handle != 0
        _sawNativeEvent = false

        _nativeSnapshot = fallbackSnapshot_()
        _nativeContentCache = buildContentCache_(_nativeSnapshot)

        if (_fallbackPolling) {
            _fallbackSnapshot = _nativeSnapshot
            _fallbackContentCache = _nativeContentCache
        }
        return this
    }

    stop() {
        if (_handle != 0) {
            NativeWatch.close(_handle)
        }
        _handle = 0
        _running = false
        return this
    }

    pending {
        if (_handle == 0) return 0
        return NativeWatch.pending(_handle)
    }

    step() {
        if (!_running || _handle == 0) return []
        var events = []
        var observedNative = false

        while (true) {
            var raw = NativeWatch.takeEvent(_handle)
            if (raw.count == 0) break
            if (raw.count > 0 && raw[0] != "error") {
                observedNative = true
            }

            for (event in buildEventsFromRaw_(raw)) {
                events.add(event)
            }
        }

        if (observedNative) {
            _sawNativeEvent = true
        } else if (_fallbackPolling && !_sawNativeEvent) {
            for (event in fallbackStep_()) {
                events.add(event)
            }
        }

        _lastEvents = events
        dispatchEvents_(events)
        return events
    }

    run() {
        if (!_running) start()
        while (_running) {
            if (_runMode == "wait") {
                waitStep_()
            } else {
                step()
                if (_running && _pollInterval > 0) {
                    Process.sleep(_pollInterval)
                }
            }
            if (_handle != 0 && !NativeWatch.has(_handle)) {
                _running = false
                _handle = 0
            }
        }
        return this
    }

    waitStep_() {
        if (!_running || _handle == 0) return []
        var events = []
        var observedNative = false

        var raw = NativeWatch.waitEvent(_handle, _waitTimeout)
        if (raw.count > 0) {
            if (raw[0] != "error") {
                observedNative = true
            }
            for (event in buildEventsFromRaw_(raw)) {
                events.add(event)
            }
        }

        while (true) {
            var queued = NativeWatch.takeEvent(_handle)
            if (queued.count == 0) break
            if (queued[0] != "error") {
                observedNative = true
            }
            for (event in buildEventsFromRaw_(queued)) {
                events.add(event)
            }
        }

        if (observedNative) {
            _sawNativeEvent = true
        } else if (_fallbackPolling && !_sawNativeEvent) {
            for (event in fallbackStep_()) {
                events.add(event)
            }
        }

        _lastEvents = events
        dispatchEvents_(events)
        return events
    }

    buildEventsFromRaw_(raw) {
        var events = []
        if (raw.count < 2) return events

        var kind = raw[0]
        var nativeTimestamp = raw[1]
        var paths = []

        if (raw.count > 2) {
            for (i in 2...raw.count) {
                paths.add(raw[i])
            }
        }

        if (paths.count == 0) {
            events.add(eventContext_(kind, null, paths, nativeTimestamp))
            return events
        }

        for (path in paths) {
            events.add(eventContext_(kind, path, paths, nativeTimestamp))
        }
        return events
    }

    fallbackStep_() {
        var nextSnapshot = fallbackSnapshot_()
        var nextContentCache = {}
        var events = []

        for (entry in nextSnapshot) {
            var path = entry.key
            var after = entry.value
            var afterContent = resolveNextContent_(path, after, _fallbackSnapshot, _fallbackContentCache)
            if (afterContent != null) {
                nextContentCache[path] = afterContent
            }

            if (!_fallbackSnapshot.containsKey(path)) {
                events.add(fallbackEventContext_("created", path, null, after, null, afterContent))
                continue
            }

            var before = _fallbackSnapshot[path]
            var beforeContent = null
            if (_fallbackContentCache.containsKey(path)) {
                beforeContent = _fallbackContentCache[path]
            }
            if (fallbackStateChanged_(before, after) || beforeContent != afterContent) {
                events.add(fallbackEventContext_("modified", path, before, after, beforeContent, afterContent))
            }
        }

        for (entry in _fallbackSnapshot) {
            var path = entry.key
            if (!nextSnapshot.containsKey(path)) {
                var beforeContent = null
                if (_fallbackContentCache.containsKey(path)) {
                    beforeContent = _fallbackContentCache[path]
                }
                events.add(fallbackEventContext_("deleted", path, entry.value, null, beforeContent, null))
            }
        }

        _fallbackSnapshot = nextSnapshot
        _fallbackContentCache = nextContentCache
        _nativeSnapshot = nextSnapshot
        _nativeContentCache = nextContentCache
        return events
    }

    fallbackSnapshot_() {
        var snapshot = {}
        fallbackCollectState_(_root, snapshot)
        return snapshot
    }

    fallbackCollectState_(path, snapshot) {
        if (!File.exists(path)) return

        var state = fallbackStateFor_(path)
        snapshot[path] = state

        if (state["isDirectory"] && _recursive) {
            for (name in Dir.list(path)) {
                fallbackCollectState_(Path.join(path, name), snapshot)
            }
        }
    }

    fallbackStateFor_(path) {
        var isDirectory = File.isDirectory(path)
        return {
            "path": path,
            "exists": true,
            "isDirectory": isDirectory,
            "size": isDirectory ? -1 : File.size(path),
            "modified": File.modified(path)
        }
    }

    fallbackStateChanged_(before, after) {
        if (before["isDirectory"] != after["isDirectory"]) return true
        if (before["size"] != after["size"]) return true
        if (before["modified"] != after["modified"]) return true
        return false
    }

    buildContentCache_(snapshot) {
        var cache = {}
        for (entry in snapshot) {
            var path = entry.key
            var state = entry.value
            if (state == null || state["isDirectory"]) continue
            cache[path] = safeReadContent_(path)
        }
        return cache
    }

    safeReadContent_(path) {
        if (!File.exists(path) || File.isDirectory(path)) return null
        return File.read(path)
    }

    resolveNextContent_(path, after, previousSnapshot, previousContentCache) {
        if (after["isDirectory"]) return null

        if (previousSnapshot.containsKey(path)) {
            var before = previousSnapshot[path]
            if (before != null && !fallbackStateChanged_(before, after) && previousContentCache.containsKey(path)) {
                return previousContentCache[path]
            }
        }

        return safeReadContent_(path)
    }

    contentDiffFor_(kind, isDirectory, beforeContent, afterContent) {
        if (isDirectory) return null

        var beforeText = beforeContent == null ? "" : beforeContent
        var afterText = afterContent == null ? "" : afterContent
        if (beforeText == afterText) return null

        var diff = lineDiff_(beforeText, afterText)
        diff["kind"] = kind
        return diff
    }

    linesForText_(text) {
        if (text == null || text == "") return []
        return Str.lines(text)
    }

    lineDiff_(beforeText, afterText) {
        var beforeLines = linesForText_(beforeText)
        var afterLines = linesForText_(afterText)

        var prefix = 0
        while (prefix < beforeLines.count && prefix < afterLines.count && beforeLines[prefix] == afterLines[prefix]) {
            prefix = prefix + 1
        }

        var beforeTail = beforeLines.count - 1
        var afterTail = afterLines.count - 1
        while (beforeTail >= prefix && afterTail >= prefix && beforeLines[beforeTail] == afterLines[afterTail]) {
            beforeTail = beforeTail - 1
            afterTail = afterTail - 1
        }

        var removed = []
        if (beforeTail >= prefix) {
            for (i in prefix..beforeTail) {
                removed.add(beforeLines[i])
            }
        }

        var added = []
        if (afterTail >= prefix) {
            for (i in prefix..afterTail) {
                added.add(afterLines[i])
            }
        }

        return {
            "algorithm": "line-prefix-suffix",
            "startLine": prefix + 1,
            "beforeLineCount": beforeLines.count,
            "afterLineCount": afterLines.count,
            "removed": removed,
            "removedCount": removed.count,
            "added": added,
            "addedCount": added.count
        }
    }

    fallbackEventContext_(kind, path, before, after, beforeContent, afterContent) {
        var isDirectory = false
        if (after != null) {
            isDirectory = after["isDirectory"]
        } else if (before != null) {
            isDirectory = before["isDirectory"]
        }

        var paths = []
        if (path != null) paths.add(path)
        var contentDiff = contentDiffFor_(kind, isDirectory, beforeContent, afterContent)
        var prettyDiff = null
        var patch = null
        var patchColor = null

        if (contentDiff != null) {
            var beforeText = beforeContent == null ? "" : beforeContent
            var afterText = afterContent == null ? "" : afterContent
            if (_includePrettyDiff) {
                prettyDiff = Diff.pretty(path, beforeText, afterText, _diffGranularity, _diffAlgorithm)
            }
            if (_includePatch) {
                patch = Diff.patch(path, beforeText, afterText)
                patchColor = Diff.patchColor(path, beforeText, afterText)
            }
        }

        return {
            "kind": kind,
            "root": _root,
            "path": path,
            "paths": paths,
            "isDirectory": isDirectory,
            "timestamp": System.clock,
            "nativeTimestamp": null,
            "native": false,
            "before": before,
            "after": after,
            "contentChanged": contentDiff != null,
            "contentDiff": contentDiff,
            "diffGranularity": _diffGranularity,
            "diffAlgorithm": _diffAlgorithm,
            "prettyDiff": prettyDiff,
            "patch": patch,
            "patchColor": patchColor
        }
    }

    eventContext_(kind, path, paths, nativeTimestamp) {
        var before = null
        var after = null
        var beforeContent = null
        var afterContent = null
        var isDirectory = false

        if (path != null) {
            if (_nativeSnapshot.containsKey(path)) {
                before = _nativeSnapshot[path]
            }
            if (_nativeContentCache.containsKey(path)) {
                beforeContent = _nativeContentCache[path]
            }

            if (File.exists(path)) {
                after = fallbackStateFor_(path)
                isDirectory = after["isDirectory"]
                _nativeSnapshot[path] = after

                if (!isDirectory) {
                    afterContent = safeReadContent_(path)
                    _nativeContentCache[path] = afterContent
                } else {
                    _nativeContentCache[path] = null
                }
            } else {
                if (before != null) {
                    isDirectory = before["isDirectory"]
                }
                _nativeSnapshot[path] = null
                _nativeContentCache[path] = null
            }
        }
        var contentDiff = contentDiffFor_(kind, isDirectory, beforeContent, afterContent)
        var prettyDiff = null
        var patch = null
        var patchColor = null

        if (contentDiff != null) {
            var beforeText = beforeContent == null ? "" : beforeContent
            var afterText = afterContent == null ? "" : afterContent
            if (_includePrettyDiff) {
                prettyDiff = Diff.pretty(path, beforeText, afterText, _diffGranularity, _diffAlgorithm)
            }
            if (_includePatch) {
                patch = Diff.patch(path, beforeText, afterText)
                patchColor = Diff.patchColor(path, beforeText, afterText)
            }
        }

        return {
            "kind": kind,
            "root": _root,
            "path": path,
            "paths": paths,
            "isDirectory": isDirectory,
            "timestamp": System.clock,
            "nativeTimestamp": nativeTimestamp,
            "native": true,
            "before": before,
            "after": after,
            "contentChanged": contentDiff != null,
            "contentDiff": contentDiff,
            "diffGranularity": _diffGranularity,
            "diffAlgorithm": _diffAlgorithm,
            "prettyDiff": prettyDiff,
            "patch": patch,
            "patchColor": patchColor
        }
    }

    dispatchEvents_(events) {
        if (_listeners.count == 0 || events.count == 0) return
        for (event in events) {
            for (handler in _listeners) {
                invokeHandler_(handler, event)
            }
        }
    }

    invokeHandler_(handler, event) {
        if (handler == null) return

        if (handler is Fiber) {
            if (!handler.isDone) {
                handler.call(event)
            }
            return
        }

        var fiber = Fiber.new { handler.call(event) }
        fiber.call()
    }
}
