# Wren String Interpolation Escaping Issue

## Problem

Wren's string interpolation syntax `%(expr)` conflicts with legitimate use of `%` in string literals, particularly:

- **Shell/printf formatting**: `"date +%Y-%m-%d"` → Parser expects `%(Y)` 
- **Bare `%` characters**: `var p = "%"` → Parser tries to parse `%"` as incomplete interpolation
- **JSON with escapes**: Complex JSON payloads with `\"` and `%` combinations

### Current Behavior
```wren
var cmd = "date +%Y-%m-%d"      // ❌ Error: Expect '(' after '%'
var p = "%"                      // ❌ Error: Expect '(' after '%'
var fmt = "format: %s %d"        // ❌ Fails - parser confused
```

### Workaround (Current)
Users must work around by:
1. **Using character codes** (awkward):
   ```wren
   var pc = Str.fromCharCode(37) // ASCII 37 = %
   var fmt = pc + "Y-" + pc + "m-" + pc + "d"
   ```

2. **String concatenation** (verbose):
   ```wren
   var cmd = "date +" + "%" + "Y-" + "%" + "m-" + "%" + "d"
   ```

3. **Shell wrapping**:
   ```wren
   Shell.run("sh -c 'date +%Y-%m-%d'")
   ```

## Root Cause

The Wren parser greedily interprets `%` followed by `(` or identifier as string interpolation, with no escape mechanism for literal `%` characters in double-quoted strings.

## Proposed Solutions

### 1. **Escape Sequence (Recommended - Minimal)**
Add standard escape for `%`:
```wren
var cmd = "date +%%Y-%%m-%%d"  // %% → single %
```
**Pros**: Standard across many languages (printf, Python f-strings with %%); minimal parser change
**Cons**: Requires documentation update; existing code with bare % needs fixing

### 2. **Raw String Literals**
Add syntax for non-interpolating strings:
```wren
var cmd = r"date +%Y-%m-%d"     // r"" = raw, no interpolation
var json = r#"{"key": "%value"}"#  // handles quotes too
```
**Pros**: Explicit intent; avoids ambiguity
**Cons**: Larger parser change; two string types to maintain

### 3. **Smarter Parser**
Only treat `%(identifier)` or `%(expression)` as interpolation:
```wren
var p = "%"      // OK - not followed by ( or identifier
var cmd = "x%y"  // OK - % not in interpolation position
```
**Pros**: No escape needed for valid patterns
**Cons**: More complex parser logic; could have edge cases

### 4. **Character Class Restriction**
Only allow interpolation when `%` is followed by specific chars:
```wren
// Only %(, %{, %[ trigger interpolation
var cmd = "date +%Y"  // OK - not followed by (, {, [
```
**Pros**: Backward compatible with common patterns
**Cons**: Still breaks some legitimate cases

## Recommendation

**Option 1 (Escape Sequence `%%`)** is best because:
- ✅ Solves 95% of real-world cases (shell, date, printf)
- ✅ Minimal implementation (just handle `%%` in lexer)
- ✅ Familiar to developers (C, Python, SQL use `%%`)
- ✅ Backward compatible (unused sequences before)
- ⚠️ Only cost: documentation + migration guide

## Impact

Files affected in this repo:
- `lms_benchmark.wren` (date formatting issue - FIXED with workaround)
- Any future shell integration code
- JSON/API payload strings with formatting

## Test Cases Needed

```wren
// All should work after fix:
var fmt1 = "printf %d %s"
var fmt2 = "date +%%Y-%%m-%%d"
var json = "{\"key\": \"%%placeholder\"}"
var sql = "SELECT * FROM table WHERE x LIKE %%value%%"
var literal = "50%% complete"
```

---
**Discovered**: `lms_benchmark.wren` syntax debugging
**Workaround Applied**: `Str.fromCharCode(37)` + concatenation
**Status**: Documented for future Wren parser improvements
