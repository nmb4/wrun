use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Output};
use tempfile::TempDir;

fn wrun_bin() -> PathBuf {
    PathBuf::from(env!("CARGO_BIN_EXE_wrun"))
}

fn run_wrun(args: &[&str], cwd: &Path, home: &Path) -> Output {
    Command::new(wrun_bin())
        .args(args)
        .current_dir(cwd)
        .env("HOME", home)
        .env("USERPROFILE", home)
        .output()
        .expect("failed to run wrun")
}

fn stdout(out: &Output) -> String {
    String::from_utf8_lossy(&out.stdout).to_string()
}

fn stderr(out: &Output) -> String {
    String::from_utf8_lossy(&out.stderr).to_string()
}

fn write_script(path: &Path, marker: &str) {
    let content = format!("System.print(\"{}\")\n", marker);
    fs::write(path, content).expect("failed to write script");
}

fn setup() -> (TempDir, PathBuf, PathBuf) {
    let tmp = TempDir::new().expect("temp dir");
    let home = tmp.path().join("home");
    let work = tmp.path().join("work");
    fs::create_dir_all(&home).expect("home dir");
    fs::create_dir_all(&work).expect("work dir");
    (tmp, home, work)
}

#[test]
fn install_run_and_create_shim() {
    let (_tmp, home, work) = setup();
    let source = work.join("tool.wren");
    write_script(&source, "INSTALLED_OK");

    let install = run_wrun(
        &[
            "registry",
            "install",
            source.to_string_lossy().as_ref(),
            "--name",
            "tool",
        ],
        &work,
        &home,
    );
    assert!(install.status.success(), "stderr: {}", stderr(&install));

    let run = run_wrun(&["tool"], &work, &home);
    assert!(run.status.success(), "stderr: {}", stderr(&run));
    assert!(
        stdout(&run).contains("INSTALLED_OK"),
        "stdout: {}",
        stdout(&run)
    );

    let shim_path = if cfg!(windows) {
        home.join(".wrun").join("bin").join("tool.cmd")
    } else {
        home.join(".wrun").join("bin").join("tool")
    };
    assert!(
        shim_path.exists(),
        "shim not found at {}",
        shim_path.display()
    );
}

#[test]
fn local_file_precedence_and_explicit_registry_run() {
    let (_tmp, home, work) = setup();

    let installed = work.join("installed.wren");
    write_script(&installed, "INSTALLED_FOO");
    let install = run_wrun(
        &[
            "registry",
            "install",
            installed.to_string_lossy().as_ref(),
            "--name",
            "foo",
        ],
        &work,
        &home,
    );
    assert!(install.status.success(), "stderr: {}", stderr(&install));

    let local = work.join("foo");
    write_script(&local, "LOCAL_FOO");

    let fallback = run_wrun(&["foo"], &work, &home);
    assert!(fallback.status.success(), "stderr: {}", stderr(&fallback));
    let fallback_out = stdout(&fallback);
    assert!(
        fallback_out.contains("LOCAL_FOO"),
        "stdout: {}",
        fallback_out
    );
    assert!(
        !fallback_out.contains("INSTALLED_FOO"),
        "stdout: {}",
        fallback_out
    );

    let explicit = run_wrun(&["registry", "run", "foo"], &work, &home);
    assert!(explicit.status.success(), "stderr: {}", stderr(&explicit));
    assert!(
        stdout(&explicit).contains("INSTALLED_FOO"),
        "stdout: {}",
        stdout(&explicit)
    );
}

#[test]
fn reinstall_requires_force_and_uninstall_removes_entry() {
    let (_tmp, home, work) = setup();

    let v1 = work.join("v1.wren");
    let v2 = work.join("v2.wren");
    write_script(&v1, "VERSION_1");
    write_script(&v2, "VERSION_2");

    let install_v1 = run_wrun(
        &[
            "registry",
            "install",
            v1.to_string_lossy().as_ref(),
            "--name",
            "app",
        ],
        &work,
        &home,
    );
    assert!(
        install_v1.status.success(),
        "stderr: {}",
        stderr(&install_v1)
    );

    let reinstall_without_force = run_wrun(
        &[
            "registry",
            "install",
            v2.to_string_lossy().as_ref(),
            "--name",
            "app",
        ],
        &work,
        &home,
    );
    assert!(
        !reinstall_without_force.status.success(),
        "stdout: {} stderr: {}",
        stdout(&reinstall_without_force),
        stderr(&reinstall_without_force)
    );
    assert!(
        stderr(&reinstall_without_force).contains("already installed"),
        "stderr: {}",
        stderr(&reinstall_without_force)
    );

    let reinstall_force = run_wrun(
        &[
            "registry",
            "install",
            v2.to_string_lossy().as_ref(),
            "--name",
            "app",
            "--force",
        ],
        &work,
        &home,
    );
    assert!(
        reinstall_force.status.success(),
        "stderr: {}",
        stderr(&reinstall_force)
    );

    let run_v2 = run_wrun(&["app"], &work, &home);
    assert!(run_v2.status.success(), "stderr: {}", stderr(&run_v2));
    assert!(
        stdout(&run_v2).contains("VERSION_2"),
        "stdout: {}",
        stdout(&run_v2)
    );

    let uninstall = run_wrun(&["registry", "uninstall", "app"], &work, &home);
    assert!(uninstall.status.success(), "stderr: {}", stderr(&uninstall));

    let run_missing = run_wrun(&["app"], &work, &home);
    assert!(
        !run_missing.status.success(),
        "stdout: {}",
        stdout(&run_missing)
    );
    assert!(
        stderr(&run_missing).contains("not found"),
        "stderr: {}",
        stderr(&run_missing)
    );

    let shim_path = if cfg!(windows) {
        home.join(".wrun").join("bin").join("app.cmd")
    } else {
        home.join(".wrun").join("bin").join("app")
    };
    assert!(
        !shim_path.exists(),
        "shim should be removed at {}",
        shim_path.display()
    );
}

#[test]
fn list_and_info_json_output() {
    let (_tmp, home, work) = setup();
    let source = work.join("json_tool.wren");
    write_script(&source, "JSON_TOOL");

    let install = run_wrun(
        &[
            "registry",
            "install",
            source.to_string_lossy().as_ref(),
            "--name",
            "json_tool",
        ],
        &work,
        &home,
    );
    assert!(install.status.success(), "stderr: {}", stderr(&install));

    let list = run_wrun(&["registry", "list", "--json"], &work, &home);
    assert!(list.status.success(), "stderr: {}", stderr(&list));
    assert!(
        stdout(&list).contains("\"name\": \"json_tool\""),
        "stdout: {}",
        stdout(&list)
    );

    let info = run_wrun(&["registry", "info", "json_tool", "--json"], &work, &home);
    assert!(info.status.success(), "stderr: {}", stderr(&info));
    let info_out = stdout(&info);
    assert!(
        info_out.contains("\"name\": \"json_tool\""),
        "stdout: {}",
        info_out
    );
    assert!(
        info_out.contains("\"source_path\":"),
        "stdout: {}",
        info_out
    );
}
