# Examples Layout

This folder is organized by feature area so examples stay discoverable.

## Folders

- `basics/`: small general scripts (`hello`, `fractal`, dry-run usage)
- `process/`: process pipeline usage patterns
- `print/`: logging/print module examples
- `file/watchers/`: interactive watcher demos
- `file/diff/`: diff/patch rendering demos
- `file/smoke/`: smoke tests for watcher + diff behavior
- `logs/`: sample/generated log output files

## Quick Runs

```bash
# Watchers
# Native-first watcher demos
cargo run --quiet -- examples/file/watchers/default_watcher_wait.wren
cargo run --quiet -- examples/file/watchers/native_poll_watcher.wren
# Explicit non-native polling demo
cargo run --quiet -- examples/file/watchers/non_native_polling_watcher.wren

# Diff helpers
cargo run --quiet -- examples/file/diff/pretty_diff_groups.wren
cargo run --quiet -- examples/file/diff/patch_roundtrip.wren

# Smoke tests
cargo run --quiet -- examples/file/smoke/non_native_content_diff.wren
cargo run --quiet -- examples/file/smoke/non_native_recursive_mode.wren
cargo run --quiet -- examples/file/smoke/native_poll_mode.wren
cargo run --quiet -- examples/file/smoke/native_wait_mode.wren
cargo run --quiet -- examples/file/smoke/default_watcher_alias_native.wren
```

Native strict probes can print `SKIP` if native content events are unavailable on the
current platform/backend configuration.
