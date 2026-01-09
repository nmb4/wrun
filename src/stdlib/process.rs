use ruwren::{wren_impl, ModuleLibrary, WrenObject};
use ruwren::foreign_v2::WrenString;
use std::process::{Command, Stdio};

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
            Command::new("cmd")
                .args(["/C", &command])
                .status()
        } else {
            Command::new("sh")
                .args(["-c", &command])
                .status()
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
            Command::new("cmd")
                .args(["/C", &command])
                .spawn()
        } else {
            Command::new("sh")
                .args(["-c", &command])
                .spawn()
        };

        result.is_ok()
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
