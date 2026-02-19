#![allow(non_snake_case)]

use diffy::{Patch, PatchFormatter, apply, create_patch};
use notify::event::ModifyKind;
use notify::{Config, Event, EventKind, RecommendedWatcher, RecursiveMode, Watcher};
use ruwren::foreign_v2::WrenString;
use ruwren::{wren_impl, ModuleLibrary, WrenObject};
use similar::{Algorithm, ChangeTag, TextDiff};
use std::collections::{HashMap, VecDeque};
use std::fmt::Write;
use std::fs;
use std::path::Path;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::mpsc::{Receiver, TryRecvError, channel};
use std::sync::{Mutex, MutexGuard};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

#[derive(WrenObject, Default)]
pub struct File;

#[wren_impl]
impl File {
    fn read(&self, path: WrenString) -> String {
        let path = path.into_string().unwrap_or_default();
        fs::read_to_string(&path).unwrap_or_default()
    }

    fn readBytes(&self, path: WrenString) -> Vec<f64> {
        let path = path.into_string().unwrap_or_default();
        fs::read(&path)
            .map(|bytes| bytes.into_iter().map(|b| b as f64).collect())
            .unwrap_or_default()
    }

    fn write(&self, path: WrenString, content: WrenString) -> bool {
        let path = path.into_string().unwrap_or_default();
        let content = content.into_string().unwrap_or_default();
        fs::write(&path, content).is_ok()
    }

    fn writeBytes(&self, path: WrenString, bytes: Vec<f64>) -> bool {
        let path = path.into_string().unwrap_or_default();
        let bytes: Vec<u8> = bytes.into_iter().map(|b| b as u8).collect();
        fs::write(&path, bytes).is_ok()
    }

    fn append(&self, path: WrenString, content: WrenString) -> bool {
        use std::fs::OpenOptions;
        use std::io::Write;

        let path = path.into_string().unwrap_or_default();
        let content = content.into_string().unwrap_or_default();
        OpenOptions::new()
            .create(true)
            .append(true)
            .open(&path)
            .and_then(|mut f| f.write_all(content.as_bytes()))
            .is_ok()
    }

    fn exists(&self, path: WrenString) -> bool {
        let path = path.into_string().unwrap_or_default();
        Path::new(&path).exists()
    }

    fn isFile(&self, path: WrenString) -> bool {
        let path = path.into_string().unwrap_or_default();
        Path::new(&path).is_file()
    }

    fn isDirectory(&self, path: WrenString) -> bool {
        let path = path.into_string().unwrap_or_default();
        Path::new(&path).is_dir()
    }

    fn delete(&self, path: WrenString) -> bool {
        let path = path.into_string().unwrap_or_default();
        let p = Path::new(&path);
        if p.is_dir() {
            fs::remove_dir_all(&path).is_ok()
        } else {
            fs::remove_file(&path).is_ok()
        }
    }

    fn copy(&self, from: WrenString, to: WrenString) -> bool {
        let from = from.into_string().unwrap_or_default();
        let to = to.into_string().unwrap_or_default();
        fs::copy(&from, &to).is_ok()
    }

    fn rename(&self, from: WrenString, to: WrenString) -> bool {
        let from = from.into_string().unwrap_or_default();
        let to = to.into_string().unwrap_or_default();
        fs::rename(&from, &to).is_ok()
    }

    fn mkdir(&self, path: WrenString) -> bool {
        let path = path.into_string().unwrap_or_default();
        fs::create_dir_all(&path).is_ok()
    }

    fn size(&self, path: WrenString) -> f64 {
        let path = path.into_string().unwrap_or_default();
        fs::metadata(&path).map(|m| m.len() as f64).unwrap_or(-1.0)
    }

    fn modified(&self, path: WrenString) -> f64 {
        let path = path.into_string().unwrap_or_default();
        fs::metadata(&path)
            .and_then(|m| m.modified())
            .ok()
            .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
            .map(|d| d.as_secs_f64())
            .unwrap_or(-1.0)
    }
}

#[derive(WrenObject, Default)]
pub struct Dir;

#[wren_impl]
impl Dir {
    fn list(&self, path: WrenString) -> Vec<String> {
        let path = path.into_string().unwrap_or_default();
        fs::read_dir(&path)
            .map(|entries| {
                entries
                    .filter_map(|e| e.ok())
                    .map(|e| e.file_name().to_string_lossy().to_string())
                    .collect()
            })
            .unwrap_or_default()
    }

    fn create(&self, path: WrenString) -> bool {
        let path = path.into_string().unwrap_or_default();
        fs::create_dir_all(&path).is_ok()
    }

    fn remove(&self, path: WrenString) -> bool {
        let path = path.into_string().unwrap_or_default();
        fs::remove_dir_all(&path).is_ok()
    }

    fn exists(&self, path: WrenString) -> bool {
        let path = path.into_string().unwrap_or_default();
        Path::new(&path).is_dir()
    }
}

#[derive(WrenObject, Default)]
pub struct PathUtil;

#[wren_impl]
impl PathUtil {
    fn join(&self, a: WrenString, b: WrenString) -> String {
        let a = a.into_string().unwrap_or_default();
        let b = b.into_string().unwrap_or_default();
        Path::new(&a).join(&b).to_string_lossy().to_string()
    }

    fn dirname(&self, path: WrenString) -> String {
        let path = path.into_string().unwrap_or_default();
        Path::new(&path)
            .parent()
            .map(|p| p.to_string_lossy().to_string())
            .unwrap_or_default()
    }

    fn basename(&self, path: WrenString) -> String {
        let path = path.into_string().unwrap_or_default();
        Path::new(&path)
            .file_name()
            .map(|p| p.to_string_lossy().to_string())
            .unwrap_or_default()
    }

    fn extension(&self, path: WrenString) -> String {
        let path = path.into_string().unwrap_or_default();
        Path::new(&path)
            .extension()
            .map(|p| p.to_string_lossy().to_string())
            .unwrap_or_default()
    }

    fn absolute(&self, path: WrenString) -> String {
        let path = path.into_string().unwrap_or_default();
        std::fs::canonicalize(&path)
            .map(|p| p.to_string_lossy().to_string())
            .unwrap_or(path)
    }

    fn isAbsolute(&self, path: WrenString) -> bool {
        let path = path.into_string().unwrap_or_default();
        Path::new(&path).is_absolute()
    }
}

static NEXT_WATCHER_HANDLE: AtomicU64 = AtomicU64::new(1);
static NATIVE_WATCHERS: Mutex<Option<HashMap<u64, NativeWatcherState>>> = Mutex::new(None);

#[derive(Default)]
struct NativeEvent {
    kind: String,
    timestamp: f64,
    paths: Vec<String>,
}

struct NativeWatcherState {
    _watcher: RecommendedWatcher,
    rx: Receiver<notify::Result<Event>>,
    queue: VecDeque<NativeEvent>,
}

fn get_native_watchers() -> MutexGuard<'static, Option<HashMap<u64, NativeWatcherState>>> {
    let mut guard = NATIVE_WATCHERS.lock().unwrap();
    if guard.is_none() {
        *guard = Some(HashMap::new());
    }
    guard
}

fn now_unix_seconds() -> f64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs_f64())
        .unwrap_or(0.0)
}

fn kind_to_string(kind: &EventKind) -> String {
    match kind {
        EventKind::Create(_) => "created".to_string(),
        EventKind::Modify(ModifyKind::Name(_)) => "renamed".to_string(),
        EventKind::Modify(_) => "modified".to_string(),
        EventKind::Remove(_) => "deleted".to_string(),
        EventKind::Access(_) => "accessed".to_string(),
        _ => "other".to_string(),
    }
}

fn normalize_event(event: Event) -> NativeEvent {
    NativeEvent {
        kind: kind_to_string(&event.kind),
        timestamp: now_unix_seconds(),
        paths: event
            .paths
            .into_iter()
            .map(|p| p.to_string_lossy().to_string())
            .collect(),
    }
}

fn drain_native_events(state: &mut NativeWatcherState) {
    loop {
        match state.rx.try_recv() {
            Ok(result) => {
                match result {
                    Ok(event) => state.queue.push_back(normalize_event(event)),
                    Err(err) => state.queue.push_back(NativeEvent {
                        kind: "error".to_string(),
                        timestamp: now_unix_seconds(),
                        paths: vec![err.to_string()],
                    }),
                }
            }
            Err(TryRecvError::Empty) | Err(TryRecvError::Disconnected) => break,
        }
    }
}

fn encode_native_event(event: NativeEvent) -> Vec<String> {
    let mut parts = Vec::with_capacity(2 + event.paths.len());
    parts.push(event.kind);
    parts.push(format!("{:.6}", event.timestamp));
    parts.extend(event.paths);
    parts
}

fn pretty_path(path: &str) -> String {
    if path.is_empty() {
        "file".to_string()
    } else {
        path.to_string()
    }
}

fn with_path_headers(patch: String, path: &str) -> String {
    let path = pretty_path(path);
    let old_header = format!("--- a/{path}");
    let new_header = format!("+++ b/{path}");
    patch
        .replacen("--- original", &old_header, 1)
        .replacen("+++ modified", &new_header, 1)
}

fn granularity_name(name: &str) -> &str {
    match name.to_ascii_lowercase().as_str() {
        "word" => "word",
        "char" => "char",
        _ => "line",
    }
}

fn algorithm_name(name: &str) -> &str {
    match name.to_ascii_lowercase().as_str() {
        "patience" => "patience",
        "lcs" => "lcs",
        _ => "myers",
    }
}

fn make_diff<'a>(
    before: &'a str,
    after: &'a str,
    granularity: &str,
    algorithm: &str,
) -> TextDiff<'a, 'a, 'a, str> {
    let mut cfg = TextDiff::configure();
    let algorithm = match algorithm_name(algorithm) {
        "patience" => Algorithm::Patience,
        "lcs" => Algorithm::Lcs,
        _ => Algorithm::Myers,
    };
    cfg.algorithm(algorithm);
    match granularity_name(granularity) {
        "word" => cfg.diff_words(before, after),
        "char" => cfg.diff_chars(before, after),
        _ => cfg.diff_lines(before, after),
    }
}

fn strip_newline(value: &str) -> &str {
    value.strip_suffix('\n').unwrap_or(value)
}

fn format_line_number(idx: Option<usize>, width: usize) -> String {
    match idx {
        Some(v) => format!("{:>width$}", v + 1, width = width),
        None => " ".repeat(width),
    }
}

fn pretty_diff_text(path: &str, before: &str, after: &str, granularity: &str, algorithm: &str) -> String {
    let path = pretty_path(path);
    let diff = make_diff(before, after, granularity, algorithm);

    let mut added = 0usize;
    let mut removed = 0usize;
    let mut max_old = 1usize;
    let mut max_new = 1usize;
    for change in diff.iter_all_changes() {
        if let Some(old_idx) = change.old_index() {
            max_old = max_old.max(old_idx + 1);
        }
        if let Some(new_idx) = change.new_index() {
            max_new = max_new.max(new_idx + 1);
        }
        match change.tag() {
            ChangeTag::Insert => added += 1,
            ChangeTag::Delete => removed += 1,
            ChangeTag::Equal => {}
        }
    }

    let mut out = String::new();
    let mode = granularity_name(granularity);
    let algo = algorithm_name(algorithm);
    let _ = writeln!(
        &mut out,
        "• Edited {path} (\x1b[32m+{added}\x1b[0m \x1b[31m-{removed}\x1b[0m) [{mode}/{algo}]"
    );

    if mode == "line" {
        let line_number_width = max_old.max(max_new).to_string().len();
        let elision_indent = 2 + line_number_width + 1 + line_number_width + 1;
        let groups = diff.grouped_ops(2);
        for (idx, group) in groups.iter().enumerate() {
            if idx > 0 {
                let _ = writeln!(&mut out, "{}\x1b[90m⋮\x1b[0m", " ".repeat(elision_indent));
            }
            for op in group {
                for change in diff.iter_changes(op) {
                    let (old_idx, new_idx) = match change.tag() {
                        ChangeTag::Delete => (change.old_index(), None),
                        ChangeTag::Insert => (None, change.new_index()),
                        ChangeTag::Equal => (change.old_index(), change.new_index()),
                    };

                    let old_num = format_line_number(old_idx, line_number_width);
                    let new_num = format_line_number(new_idx, line_number_width);
                    let text = strip_newline(change.value());
                    let _ = write!(
                        &mut out,
                        "  \x1b[90m{old_num}\x1b[0m \x1b[90m{new_num}\x1b[0m "
                    );

                    match change.tag() {
                        ChangeTag::Delete => {
                            if text.is_empty() {
                                let _ = writeln!(&mut out, "\x1b[31m-\x1b[0m");
                            } else {
                                let _ = writeln!(&mut out, "\x1b[31m-{text}\x1b[0m");
                            }
                        }
                        ChangeTag::Insert => {
                            if text.is_empty() {
                                let _ = writeln!(&mut out, "\x1b[32m+\x1b[0m");
                            } else {
                                let _ = writeln!(&mut out, "\x1b[32m+{text}\x1b[0m");
                            }
                        }
                        ChangeTag::Equal => {
                            if text.is_empty() {
                                let _ = writeln!(&mut out, " ");
                            } else {
                                let _ = writeln!(&mut out, " {text}");
                            }
                        }
                    }
                }
            }
        }
    } else {
        let _ = writeln!(
            &mut out,
            "    \x1b[90mGranularity: {mode} (inline token view)\x1b[0m"
        );
        let _ = write!(&mut out, "    ");
        for change in diff.iter_all_changes() {
            match change.tag() {
                ChangeTag::Delete => {
                    let _ = write!(&mut out, "\x1b[31m{}\x1b[0m", change.value());
                }
                ChangeTag::Insert => {
                    let _ = write!(&mut out, "\x1b[32m{}\x1b[0m", change.value());
                }
                ChangeTag::Equal => {
                    let _ = write!(&mut out, "{}", change.value());
                }
            }
        }
        if !out.ends_with('\n') {
            out.push('\n');
        }
    }

    out
}

#[derive(WrenObject, Default)]
pub struct DiffUtil;

#[wren_impl]
impl DiffUtil {
    fn pretty(
        &self,
        path: WrenString,
        before: WrenString,
        after: WrenString,
        granularity: WrenString,
        algorithm: WrenString,
    ) -> String {
        let path = path.into_string().unwrap_or_default();
        let before = before.into_string().unwrap_or_default();
        let after = after.into_string().unwrap_or_default();
        let granularity = granularity
            .into_string()
            .unwrap_or_else(|_| "line".to_string());
        let algorithm = algorithm
            .into_string()
            .unwrap_or_else(|_| "myers".to_string());
        pretty_diff_text(&path, &before, &after, &granularity, &algorithm)
    }

    fn patch(&self, path: WrenString, before: WrenString, after: WrenString) -> String {
        let path = path.into_string().unwrap_or_default();
        let before = before.into_string().unwrap_or_default();
        let after = after.into_string().unwrap_or_default();
        with_path_headers(create_patch(&before, &after).to_string(), &path)
    }

    fn patchColor(&self, path: WrenString, before: WrenString, after: WrenString) -> String {
        let path = path.into_string().unwrap_or_default();
        let before = before.into_string().unwrap_or_default();
        let after = after.into_string().unwrap_or_default();
        let patch = create_patch(&before, &after);
        let formatter = PatchFormatter::new().with_color();
        let rendered = format!("{}", formatter.fmt_patch(&patch));
        with_path_headers(rendered, &path)
    }

    fn applyPatchResult(&self, base: WrenString, patch_text: WrenString) -> Vec<String> {
        let base = base.into_string().unwrap_or_default();
        let patch_text = patch_text.into_string().unwrap_or_default();

        match Patch::from_str(&patch_text) {
            Ok(patch) => match apply(&base, &patch) {
                Ok(result) => vec!["ok".to_string(), result],
                Err(err) => vec!["error".to_string(), err.to_string()],
            },
            Err(err) => vec!["error".to_string(), err.to_string()],
        }
    }
}

#[derive(WrenObject, Default)]
pub struct NativeWatch;

#[wren_impl]
impl NativeWatch {
    fn watch(&self, path: WrenString, recursive: bool) -> f64 {
        let path = path.into_string().unwrap_or_default();
        let (tx, rx) = channel();
        let mut watcher = match RecommendedWatcher::new(
            move |result| {
                let _ = tx.send(result);
            },
            Config::default(),
        ) {
            Ok(w) => w,
            Err(_) => return 0.0,
        };

        let mode = if recursive {
            RecursiveMode::Recursive
        } else {
            RecursiveMode::NonRecursive
        };
        if watcher.watch(Path::new(&path), mode).is_err() {
            return 0.0;
        }

        let handle = NEXT_WATCHER_HANDLE.fetch_add(1, Ordering::SeqCst);
        let mut watchers = get_native_watchers();
        watchers.as_mut().unwrap().insert(
            handle,
            NativeWatcherState {
                _watcher: watcher,
                rx,
                queue: VecDeque::new(),
            },
        );
        handle as f64
    }

    fn has(&self, handle: f64) -> bool {
        let handle = handle as u64;
        let watchers = get_native_watchers();
        watchers
            .as_ref()
            .map(|map| map.contains_key(&handle))
            .unwrap_or(false)
    }

    fn close(&self, handle: f64) -> bool {
        let handle = handle as u64;
        let mut watchers = get_native_watchers();
        watchers.as_mut().unwrap().remove(&handle).is_some()
    }

    fn closeAll(&self) -> f64 {
        let mut watchers = get_native_watchers();
        let map = watchers.as_mut().unwrap();
        let count = map.len();
        map.clear();
        count as f64
    }

    fn pending(&self, handle: f64) -> f64 {
        let handle = handle as u64;
        let mut watchers = get_native_watchers();
        let map = watchers.as_mut().unwrap();

        if let Some(state) = map.get_mut(&handle) {
            drain_native_events(state);
            state.queue.len() as f64
        } else {
            -1.0
        }
    }

    fn takeEvent(&self, handle: f64) -> Vec<String> {
        let handle = handle as u64;
        let mut watchers = get_native_watchers();
        let map = watchers.as_mut().unwrap();

        let Some(state) = map.get_mut(&handle) else {
            return Vec::new();
        };

        drain_native_events(state);
        if let Some(event) = state.queue.pop_front() {
            encode_native_event(event)
        } else {
            Vec::new()
        }
    }

    fn waitEvent(&self, handle: f64, timeout_seconds: f64) -> Vec<String> {
        let handle = handle as u64;
        let mut watchers = get_native_watchers();
        let map = watchers.as_mut().unwrap();

        let Some(state) = map.get_mut(&handle) else {
            return Vec::new();
        };

        drain_native_events(state);
        if let Some(event) = state.queue.pop_front() {
            return encode_native_event(event);
        }

        let received = if timeout_seconds < 0.0 {
            state.rx.recv().ok()
        } else if timeout_seconds > 0.0 && timeout_seconds.is_finite() {
            state
                .rx
                .recv_timeout(Duration::from_secs_f64(timeout_seconds))
                .ok()
        } else {
            state.rx.try_recv().ok()
        };

        if let Some(result) = received {
            match result {
                Ok(event) => state.queue.push_back(normalize_event(event)),
                Err(err) => state.queue.push_back(NativeEvent {
                    kind: "error".to_string(),
                    timestamp: now_unix_seconds(),
                    paths: vec![err.to_string()],
                }),
            }
            drain_native_events(state);
        }

        if let Some(event) = state.queue.pop_front() {
            encode_native_event(event)
        } else {
            Vec::new()
        }
    }
}

ruwren::wren_module! {
    mod wrun_file {
        pub crate::stdlib::file::File;
        pub crate::stdlib::file::Dir;
        pub crate::stdlib::file::PathUtil;
        pub crate::stdlib::file::NativeWatch;
        pub crate::stdlib::file::DiffUtil;
    }
}

pub fn publish_module(lib: &mut ModuleLibrary) {
    wrun_file::publish_module(lib);
}
