# TODO

## Bug: `Log.trace()` vs `Log.custom("trace")` filtering inconsistency

**Location:** `src/stdlib/print.rs`

**Problem:**  
`Log.trace(msg)` and `Log.trace(msg, kv)` use priority level `0` which gets filtered by the default terminal level (`2 = INFO`). However, `Log.custom("trace", msg)` does NOT get filtered because:

1. `find_custom_level("trace")` returns `None` (since "trace" isn't registered as a custom level)
2. The fallback in `custom()` and `customKv()` uses priority `5` (above ERROR)
3. Priority `5` always passes the `should_log_terminal()` check

**Expected behavior:**  
`Log.custom("trace", ...)` should behave identically to `Log.trace(...)` - both should be filtered when terminal level is set to INFO or higher.

**Fix options:**

1. In `custom()` and `customKv()`, check if the level name matches a built-in level (trace/debug/info/warn/error) and use its priority instead of falling back to `5`

2. Or, pre-register the built-in levels as custom levels with their correct priorities

**Workaround used:**  
In `pipeline.wren`, we use `Log.custom("trace", ...)` instead of `Log.trace(...)` so pipeline logs always show. This is actually desirable for now since pipeline internals should be visible, but it's inconsistent behavior that should be fixed.

**Code references:**
- `src/stdlib/print.rs:422-440` - `custom()` function with fallback to priority 5
- `src/stdlib/print.rs:442-460` - `customKv()` function with same issue
- `src/stdlib/print.rs:258-264` - `should_log_terminal()` filtering logic
