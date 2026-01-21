use ruwren::foreign_v2::WrenString;
use ruwren::{ModuleLibrary, WrenObject, wren_impl};
use std::collections::HashMap;
use std::process::{Child, Command, Stdio};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Mutex;

static NEXT_HANDLE: AtomicU64 = AtomicU64::new(1);
static ASYNC_PROCESSES: Mutex<Option<HashMap<u64, AsyncProcess>>> = Mutex::new(None);

struct AsyncProcess {
    child: Child,
    stdout: Option<String>,
    stderr: Option<String>,
    exit_code: Option<i32>,
}

fn get_processes() -> std::sync::MutexGuard<'static, Option<HashMap<u64, AsyncProcess>>> {
    let mut guard = ASYNC_PROCESSES.lock().unwrap();
    if guard.is_none() {
        *guard = Some(HashMap::new());
    }
    guard
}

#[derive(WrenObject, Default)]
pub struct Process;

#[wren_impl]
impl Process {
    fn cwd(&self) -> String {
        std::env::current_dir()
            .map(|p| p.to_string_lossy().to_string())
            .unwrap_or_default()
    }

    fn chdir(&self, path: WrenString) -> bool {
        let path = path.into_string().unwrap_or_default();
        std::env::set_current_dir(&path).is_ok()
    }

    fn exit(&self, code: f64) {
        std::process::exit(code as i32);
    }
}

#[derive(WrenObject, Default)]
pub struct Shell {
    #[wren(static_member)]
    last_stdout: String,
    #[wren(static_member)]
    last_stderr: String,
    #[wren(static_member)]
    last_exit_code: i32,
    #[wren(static_member)]
    last_success: bool,
}

#[wren_impl]
impl Shell {
    fn run(&mut self, command: WrenString) -> bool {
        let command = command.into_string().unwrap_or_default();
        let output = if cfg!(target_os = "windows") {
            Command::new("cmd")
                .args(["/C", &command])
                .stdout(Stdio::piped())
                .stderr(Stdio::piped())
                .output()
        } else {
            Command::new("sh")
                .args(["-c", &command])
                .stdout(Stdio::piped())
                .stderr(Stdio::piped())
                .output()
        };

        match output {
            Ok(output) => {
                self.last_stdout = String::from_utf8_lossy(&output.stdout).to_string();
                self.last_stderr = String::from_utf8_lossy(&output.stderr).to_string();
                self.last_exit_code = output.status.code().unwrap_or(-1);
                self.last_success = output.status.success();
                output.status.success()
            }
            Err(e) => {
                self.last_stdout = String::new();
                self.last_stderr = e.to_string();
                self.last_exit_code = -1;
                self.last_success = false;
                false
            }
        }
    }

    #[wren_impl(getter)]
    fn stdout(&self) -> String {
        self.last_stdout.clone()
    }

    #[wren_impl(getter)]
    fn stderr(&self) -> String {
        self.last_stderr.clone()
    }

    #[wren_impl(getter)]
    fn exitCode(&self) -> f64 {
        self.last_exit_code as f64
    }

    #[wren_impl(getter)]
    fn success(&self) -> bool {
        self.last_success
    }

    fn exec(&mut self, command: WrenString) -> f64 {
        let command = command.into_string().unwrap_or_default();
        let status = if cfg!(target_os = "windows") {
            Command::new("cmd").args(["/C", &command]).status()
        } else {
            Command::new("sh").args(["-c", &command]).status()
        };

        match status {
            Ok(s) => s.code().unwrap_or(-1) as f64,
            Err(_) => -1.0,
        }
    }

    fn interactive(&mut self, command: WrenString) -> f64 {
        let command = command.into_string().unwrap_or_default();
        let status = if cfg!(target_os = "windows") {
            Command::new("cmd")
                .args(["/C", &command])
                .stdin(Stdio::inherit())
                .stdout(Stdio::inherit())
                .stderr(Stdio::inherit())
                .status()
        } else {
            Command::new("sh")
                .args(["-c", &command])
                .stdin(Stdio::inherit())
                .stdout(Stdio::inherit())
                .stderr(Stdio::inherit())
                .status()
        };

        match status {
            Ok(s) => {
                self.last_exit_code = s.code().unwrap_or(-1);
                self.last_success = s.success();
                self.last_exit_code as f64
            }
            Err(_) => {
                self.last_exit_code = -1;
                self.last_success = false;
                -1.0
            }
        }
    }

    fn spawn(&self, command: WrenString) -> bool {
        let command = command.into_string().unwrap_or_default();
        let result = if cfg!(target_os = "windows") {
            Command::new("cmd").args(["/C", &command]).spawn()
        } else {
            Command::new("sh").args(["-c", &command]).spawn()
        };

        result.is_ok()
    }

    /// Spawn a command asynchronously, returning a handle ID.
    /// Returns 0 on failure, otherwise a positive handle ID.
    fn spawnAsync(&self, command: WrenString) -> f64 {
        let command = command.into_string().unwrap_or_default();
        let child_result = if cfg!(target_os = "windows") {
            Command::new("cmd")
                .args(["/C", &command])
                .stdout(Stdio::piped())
                .stderr(Stdio::piped())
                .spawn()
        } else {
            Command::new("sh")
                .args(["-c", &command])
                .stdout(Stdio::piped())
                .stderr(Stdio::piped())
                .spawn()
        };

        match child_result {
            Ok(child) => {
                let handle = NEXT_HANDLE.fetch_add(1, Ordering::SeqCst);
                let mut procs = get_processes();
                procs.as_mut().unwrap().insert(
                    handle,
                    AsyncProcess {
                        child,
                        stdout: None,
                        stderr: None,
                        exit_code: None,
                    },
                );
                handle as f64
            }
            Err(_) => 0.0,
        }
    }

    /// Check if an async process is done (non-blocking).
    /// Returns true if finished, false if still running.
    fn isDone(&self, handle: f64) -> bool {
        let handle = handle as u64;
        let mut procs = get_processes();
        let map = procs.as_mut().unwrap();

        if let Some(proc) = map.get_mut(&handle) {
            if proc.exit_code.is_some() {
                return true;
            }
            match proc.child.try_wait() {
                Ok(Some(status)) => {
                    let stdout = proc
                        .child
                        .stdout
                        .take()
                        .map(|mut s| {
                            let mut buf = String::new();
                            use std::io::Read;
                            let _ = s.read_to_string(&mut buf);
                            buf
                        })
                        .unwrap_or_default();
                    let stderr = proc
                        .child
                        .stderr
                        .take()
                        .map(|mut s| {
                            let mut buf = String::new();
                            use std::io::Read;
                            let _ = s.read_to_string(&mut buf);
                            buf
                        })
                        .unwrap_or_default();
                    proc.stdout = Some(stdout);
                    proc.stderr = Some(stderr);
                    proc.exit_code = Some(status.code().unwrap_or(-1));
                    true
                }
                Ok(None) => false,
                Err(_) => true,
            }
        } else {
            true
        }
    }

    /// Wait for an async process to complete (blocking).
    /// Returns exit code, or -1 on error.
    fn wait(&mut self, handle: f64) -> f64 {
        let handle = handle as u64;
        let mut procs = get_processes();
        let map = procs.as_mut().unwrap();

        if let Some(proc) = map.get_mut(&handle) {
            if let Some(code) = proc.exit_code {
                self.last_stdout = proc.stdout.clone().unwrap_or_default();
                self.last_stderr = proc.stderr.clone().unwrap_or_default();
                self.last_exit_code = code;
                self.last_success = code == 0;
                return code as f64;
            }
            match proc.child.wait() {
                Ok(status) => {
                    let stdout = proc
                        .child
                        .stdout
                        .take()
                        .map(|mut s| {
                            let mut buf = String::new();
                            use std::io::Read;
                            let _ = s.read_to_string(&mut buf);
                            buf
                        })
                        .unwrap_or_default();
                    let stderr = proc
                        .child
                        .stderr
                        .take()
                        .map(|mut s| {
                            let mut buf = String::new();
                            use std::io::Read;
                            let _ = s.read_to_string(&mut buf);
                            buf
                        })
                        .unwrap_or_default();
                    let code = status.code().unwrap_or(-1);
                    proc.stdout = Some(stdout.clone());
                    proc.stderr = Some(stderr.clone());
                    proc.exit_code = Some(code);
                    self.last_stdout = stdout;
                    self.last_stderr = stderr;
                    self.last_exit_code = code;
                    self.last_success = code == 0;
                    code as f64
                }
                Err(_) => {
                    self.last_exit_code = -1;
                    self.last_success = false;
                    -1.0
                }
            }
        } else {
            -1.0
        }
    }

    /// Get stdout from a completed async process.
    fn getStdout(&self, handle: f64) -> String {
        let handle = handle as u64;
        let procs = get_processes();
        procs
            .as_ref()
            .and_then(|m| m.get(&handle))
            .and_then(|p| p.stdout.clone())
            .unwrap_or_default()
    }

    /// Get stderr from a completed async process.
    fn getStderr(&self, handle: f64) -> String {
        let handle = handle as u64;
        let procs = get_processes();
        procs
            .as_ref()
            .and_then(|m| m.get(&handle))
            .and_then(|p| p.stderr.clone())
            .unwrap_or_default()
    }

    /// Get exit code from a completed async process. Returns -1 if not done or not found.
    fn getExitCode(&self, handle: f64) -> f64 {
        let handle = handle as u64;
        let procs = get_processes();
        procs
            .as_ref()
            .and_then(|m| m.get(&handle))
            .and_then(|p| p.exit_code)
            .unwrap_or(-1) as f64
    }

    /// Clean up a completed async process handle.
    fn cleanup(&self, handle: f64) -> bool {
        let handle = handle as u64;
        let mut procs = get_processes();
        procs.as_mut().unwrap().remove(&handle).is_some()
    }
}

ruwren::wren_module! {
    mod wrun_process {
        pub crate::stdlib::process::Process;
        pub crate::stdlib::process::Shell;
    }
}

pub fn publish_module(lib: &mut ModuleLibrary) {
    wrun_process::publish_module(lib);
}
