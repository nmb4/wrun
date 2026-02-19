# AGENTS.md

Operational notes for agents working in this repository.

## Project Snapshot

- Language/runtime: Rust + Wren (`wrun` CLI)
- Core docs:
  - `README.md`
  - `MODULE_REFERENCE.md`
  - `examples/README.md`
- Key implementation files for file/diff/watcher features:
  - `src/stdlib/file.rs` (Rust foreign impl)
  - `src/stdlib/wren/file.wren` (Wren API/wrappers)

## Examples Layout (Canonical)

- `examples/basics/`
- `examples/process/`
- `examples/print/`
- `examples/file/watchers/`
- `examples/file/diff/`
- `examples/file/smoke/`
- `examples/logs/`

If you move or rename examples, update:
- `README.md` (run commands section)
- `examples/README.md`
- Any hardcoded `path` literals inside example scripts

## Watcher/Diff Context

- Two watcher models exist:
  - `FileWatcher` (polling snapshot diff)
  - `NativeFileWatcher` (OS-native events with optional fallback polling)
- Default user-facing watcher alias:
  - `Watcher` -> native-backed (`NativeFileWatcher`)
  - Use `FileWatcher` explicitly for non-native behavior.
- `NativeFileWatcher` supports run modes:
  - `"poll"`
  - `"wait"` (blocking wait model)
- Fallback polling exists intentionally for robustness when native events are not yet observed.

### Diff stack

- Lightweight event summary diff: `contentDiff` (`line-prefix-suffix`) in Wren watcher code.
- Rich rendering/patch features:
  - `similar` for pretty diffs (`line` / `word` / `char`, algorithm selectable)
  - `diffy` for unified patches and patch apply.

### Current pretty-diff style expectations

- Header: `• Edited ... (+X -Y)` with colored counts.
- Line numbers: gray.
- Unchanged content: default color.
- Insert/delete content: green/red.
- Group elision `⋮`: gray and aligned with the `+/-` column.
- Left indentation before line numbers: 2 spaces.

## Public API Notes (file module)

- Diff utility:
  - `Diff.pretty(path, before, after[, granularity[, algorithm]])`
  - `Diff.patch(path, before, after)`
  - `Diff.patchColor(path, before, after)`
  - `Diff.applyPatchResult(base, patchText)`
- Watcher config:
  - `.diffGranularity("line"|"word"|"char")`
  - `.diffAlgorithm("myers"|"patience"|"lcs")`
  - `.includePrettyDiff(bool)`
  - `.includePatch(bool)`

## Smoke Tests (Keep These)

Smoke tests are intentionally kept as regular example scripts and should remain in-repo:

- `examples/file/smoke/non_native_content_diff.wren`
- `examples/file/smoke/non_native_recursive_mode.wren`
- `examples/file/smoke/native_poll_mode.wren`
- `examples/file/smoke/native_wait_mode.wren`
- `examples/file/smoke/default_watcher_alias_native.wren`
- `examples/file/smoke/default_watch_file_helper.wren`
- `examples/file/smoke/default_watch_dir_helper.wren`

Native strict probes may emit `SKIP` instead of `PASS` when native content events are
not observed on the current platform/backend.

Run from project root:

```bash
cargo run --quiet -- examples/file/smoke/non_native_content_diff.wren
cargo run --quiet -- examples/file/smoke/non_native_recursive_mode.wren
cargo run --quiet -- examples/file/smoke/native_poll_mode.wren
cargo run --quiet -- examples/file/smoke/native_wait_mode.wren
cargo run --quiet -- examples/file/smoke/default_watcher_alias_native.wren
cargo run --quiet -- examples/file/smoke/default_watch_file_helper.wren
cargo run --quiet -- examples/file/smoke/default_watch_dir_helper.wren
```

## Validation Checklist For Changes

When touching watchers/diff/examples/docs:

1. `cargo check`
2. Run all watcher smoke scripts above
3. Run at least one diff demo:
   - `examples/file/diff/pretty_diff_groups.wren`
   - `examples/file/diff/patch_roundtrip.wren`
4. Ensure `README.md` / `MODULE_REFERENCE.md` / `examples/README.md` stay in sync

## Known Non-Blocking Warnings

- `src/stdlib/process.rs` emits existing `non_snake_case` warnings (foreign API names).
- Treat as known baseline unless explicitly asked to refactor them.
