#![allow(non_snake_case)]

use notify::event::ModifyKind;
use notify::{Config, Event, EventKind, RecommendedWatcher, RecursiveMode, Watcher};
use ruwren::foreign_v2::WrenString;
use ruwren::{wren_impl, ModuleLibrary, WrenObject};
use std::collections::{HashMap, VecDeque};
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
    }
}

pub fn publish_module(lib: &mut ModuleLibrary) {
    wrun_file::publish_module(lib);
}
