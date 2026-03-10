mod registry;
mod stdlib;

use crate::registry::{Registry, RegistryEntry, RegistryError};
use crate::stdlib::process::set_dry_run;
use clap::{Parser, Subcommand};
use ruwren::{BasicFileLoader, ModuleLibrary, VMConfig};
use std::path::PathBuf;
use std::process::ExitCode;

#[derive(Parser)]
#[command(name = "wrun")]
#[command(about = "A CLI runner for Wren scripts with system integration")]
#[command(version)]
struct Cli {
    #[command(subcommand)]
    command: Option<Command>,

    /// Evaluate Wren code directly instead of reading from a file
    #[arg(short = 'e', long = "eval", value_name = "CODE")]
    eval: Option<String>,

    /// Print shell commands instead of executing them
    #[arg(long = "dry-run")]
    dry_run: bool,

    /// The Wren script path or installed registry name
    script: Option<String>,

    /// Arguments to pass to the script
    #[arg(trailing_var_arg = true, allow_hyphen_values = true)]
    args: Vec<String>,
}

#[derive(Subcommand)]
enum Command {
    /// Manage local wrun script registry
    Registry {
        #[command(subcommand)]
        command: RegistryCommand,
    },
}

#[derive(Subcommand)]
enum RegistryCommand {
    /// Install a script into the local registry
    Install {
        /// Source script path
        source: PathBuf,
        /// Install name (defaults to source file stem)
        #[arg(long = "name")]
        name: Option<String>,
        /// Replace existing script with same name
        #[arg(long = "force")]
        force: bool,
        /// Skip creating a shim in ~/.wrun/bin
        #[arg(long = "no-shim")]
        no_shim: bool,
    },
    /// Remove an installed script
    Uninstall {
        /// Installed script name
        name: String,
    },
    /// List installed scripts
    List {
        /// Print machine-readable JSON
        #[arg(long = "json")]
        json: bool,
    },
    /// Show one installed script
    Info {
        /// Installed script name
        name: String,
        /// Print machine-readable JSON
        #[arg(long = "json")]
        json: bool,
    },
    /// Run an installed script explicitly
    Run {
        /// Installed script name
        name: String,
        /// Arguments passed to the script
        #[arg(trailing_var_arg = true, allow_hyphen_values = true)]
        args: Vec<String>,
    },
}

fn main() -> ExitCode {
    let cli = Cli::parse();
    set_dry_run(cli.dry_run);

    if let Some(command) = cli.command {
        return handle_command(command, cli.dry_run);
    }

    if let Some(eval_code) = cli.eval {
        return run_source(
            eval_code,
            PathBuf::from("."),
            Some("eval".to_string()),
            cli.args,
        );
    }

    let Some(script_token) = cli.script else {
        eprintln!("No script provided. Use `wrun <script>` or `wrun registry ...`.");
        return ExitCode::FAILURE;
    };

    // Local file path always wins over registry fallback.
    let direct_path = PathBuf::from(&script_token);
    if direct_path.exists() {
        return run_script_from_path(direct_path, cli.args, None);
    }

    if is_registry_candidate(&script_token) {
        let registry = match Registry::new() {
            Ok(registry) => registry,
            Err(err) => {
                eprintln!("Failed to initialize registry: {}", err);
                return ExitCode::FAILURE;
            }
        };

        match registry.get(&script_token) {
            Ok(Some(entry)) => {
                return run_script_from_path(
                    PathBuf::from(entry.script_path),
                    cli.args,
                    Some(entry.name),
                );
            }
            Ok(None) => {}
            Err(RegistryError::InvalidName(_)) => {}
            Err(err) => {
                eprintln!("Registry lookup failed: {}", err);
                return ExitCode::FAILURE;
            }
        }
    }

    eprintln!(
        "Script '{}' was not found as a file path or installed registry entry.",
        script_token
    );
    eprintln!(
        "Try `wrun registry install <path-to-script.wren> --name {}` or `wrun registry list`.",
        script_token
    );
    ExitCode::FAILURE
}

fn handle_command(command: Command, dry_run: bool) -> ExitCode {
    match command {
        Command::Registry { command } => handle_registry_command(command, dry_run),
    }
}

fn handle_registry_command(command: RegistryCommand, dry_run: bool) -> ExitCode {
    let registry = match Registry::new() {
        Ok(r) => r,
        Err(err) => {
            eprintln!("Failed to initialize registry: {}", err);
            return ExitCode::FAILURE;
        }
    };

    match command {
        RegistryCommand::Install {
            source,
            name,
            force,
            no_shim,
        } => match registry.install(&source, name.as_deref(), force, !no_shim) {
            Ok(outcome) => {
                println!(
                    "Installed '{}' from '{}' to '{}'.",
                    outcome.entry.name, outcome.entry.source_path, outcome.entry.script_path
                );
                if let Some(shim_path) = outcome.shim_path {
                    println!("Created shim at '{}'.", shim_path.display());
                }
                maybe_print_path_hint(&registry);
                ExitCode::SUCCESS
            }
            Err(err) => {
                eprintln!("Install failed: {}", err);
                ExitCode::FAILURE
            }
        },
        RegistryCommand::Uninstall { name } => match registry.uninstall(&name) {
            Ok(()) => {
                println!("Uninstalled '{}'.", name);
                ExitCode::SUCCESS
            }
            Err(err) => {
                eprintln!("Uninstall failed: {}", err);
                ExitCode::FAILURE
            }
        },
        RegistryCommand::List { json } => match registry.list() {
            Ok(entries) => {
                if json {
                    match serde_json::to_string_pretty(&entries) {
                        Ok(text) => println!("{}", text),
                        Err(err) => {
                            eprintln!("Failed to render JSON: {}", err);
                            return ExitCode::FAILURE;
                        }
                    }
                } else if entries.is_empty() {
                    println!("No scripts installed.");
                } else {
                    for entry in entries {
                        println!(
                            "{} -> {} (installed: {})",
                            entry.name, entry.source_path, entry.installed_at
                        );
                    }
                    maybe_print_path_hint(&registry);
                }
                ExitCode::SUCCESS
            }
            Err(err) => {
                eprintln!("List failed: {}", err);
                ExitCode::FAILURE
            }
        },
        RegistryCommand::Info { name, json } => match registry.get(&name) {
            Ok(Some(entry)) => render_registry_info(&entry, json),
            Ok(None) => {
                eprintln!("Script '{}' is not installed.", name);
                ExitCode::FAILURE
            }
            Err(err) => {
                eprintln!("Info failed: {}", err);
                ExitCode::FAILURE
            }
        },
        RegistryCommand::Run { name, args } => match registry.get(&name) {
            Ok(Some(entry)) => {
                set_dry_run(dry_run);
                run_script_from_path(PathBuf::from(entry.script_path), args, Some(entry.name))
            }
            Ok(None) => {
                eprintln!("Script '{}' is not installed.", name);
                ExitCode::FAILURE
            }
            Err(err) => {
                eprintln!("Run failed: {}", err);
                ExitCode::FAILURE
            }
        },
    }
}

fn render_registry_info(entry: &RegistryEntry, json: bool) -> ExitCode {
    if json {
        match serde_json::to_string_pretty(entry) {
            Ok(text) => println!("{}", text),
            Err(err) => {
                eprintln!("Failed to render JSON: {}", err);
                return ExitCode::FAILURE;
            }
        }
    } else {
        println!("name: {}", entry.name);
        println!("source_path: {}", entry.source_path);
        println!("script_path: {}", entry.script_path);
        println!("installed_at: {}", entry.installed_at);
        println!("sha256: {}", entry.sha256);
    }
    ExitCode::SUCCESS
}

fn run_script_from_path(
    script_path: PathBuf,
    args: Vec<String>,
    script_name_override: Option<String>,
) -> ExitCode {
    let source = match std::fs::read_to_string(&script_path) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("Error reading script '{}': {}", script_path.display(), e);
            return ExitCode::FAILURE;
        }
    };

    let script_dir = script_path
        .parent()
        .map(|p| p.to_path_buf())
        .unwrap_or_else(|| PathBuf::from("."));
    let script_name = script_name_override.or_else(|| {
        script_path
            .file_stem()
            .map(|stem| stem.to_string_lossy().to_string())
    });

    run_source(source, script_dir, script_name, args)
}

fn run_source(
    source: String,
    script_dir: PathBuf,
    script_name: Option<String>,
    args: Vec<String>,
) -> ExitCode {
    let mut lib = ModuleLibrary::new();
    stdlib::publish_modules(&mut lib);
    let vm = VMConfig::new()
        .library(&lib)
        .script_loader(BasicFileLoader::new().base_dir(script_dir.clone()))
        .build();

    let stdlib_src = stdlib::get_stdlib_source();
    if let Err(e) = vm.interpret("wrun/process", stdlib_src.process) {
        eprintln!("{}", e);
        return ExitCode::FAILURE;
    }
    if let Err(e) = vm.interpret("wrun/str", stdlib_src.str) {
        eprintln!("{}", e);
        return ExitCode::FAILURE;
    }
    if let Err(e) = vm.interpret("wrun/file", stdlib_src.file) {
        eprintln!("{}", e);
        return ExitCode::FAILURE;
    }
    if let Err(e) = vm.interpret("wrun/env", stdlib_src.env) {
        eprintln!("{}", e);
        return ExitCode::FAILURE;
    }
    if let Err(e) = vm.interpret("wrun/args", stdlib_src.args) {
        eprintln!("{}", e);
        return ExitCode::FAILURE;
    }
    if let Err(e) = vm.interpret("wrun/print", stdlib_src.print) {
        eprintln!("{}", e);
        return ExitCode::FAILURE;
    }
    if let Err(e) = vm.interpret("wrun/pipeline", stdlib_src.pipeline) {
        eprintln!("{}", e);
        return ExitCode::FAILURE;
    }

    stdlib::args::set_args(args);
    stdlib::print::set_script_dir(script_dir.to_string_lossy().to_string());
    if let Some(name) = script_name {
        stdlib::print::set_script_name(name);
    }

    if let Err(e) = vm.interpret("main", &source) {
        eprintln!("{}", e);
        return ExitCode::FAILURE;
    }

    ExitCode::SUCCESS
}

fn maybe_print_path_hint(registry: &Registry) {
    if registry.is_bin_on_path() {
        return;
    }
    println!(
        "Tip: add '{}' to PATH to run installed scripts directly.",
        registry.bin_dir().display()
    );
    println!("Example: {}", registry.path_hint());
}

fn is_registry_candidate(token: &str) -> bool {
    !token.is_empty()
        && token
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || c == '.' || c == '-' || c == '_')
}
