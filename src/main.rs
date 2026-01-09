mod stdlib;

use clap::Parser;
use ruwren::{BasicFileLoader, ModuleLibrary, VMConfig};
use std::path::PathBuf;
use std::process::ExitCode;

#[derive(Parser)]
#[command(name = "wrun")]
#[command(about = "A CLI runner for Wren scripts with system integration")]
#[command(version)]
struct Cli {
    /// The Wren script to execute
    script: PathBuf,

    /// Arguments to pass to the script
    #[arg(trailing_var_arg = true)]
    args: Vec<String>,
}

fn main() -> ExitCode {
    let cli = Cli::parse();

    let script_path = &cli.script;
    let source = match std::fs::read_to_string(script_path) {
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

    let mut lib = ModuleLibrary::new();
    stdlib::publish_modules(&mut lib);

    let vm = VMConfig::new()
        .library(&lib)
        .script_loader(BasicFileLoader::new().base_dir(script_dir))
        .build();

    let stdlib_src = stdlib::get_stdlib_source();
    if let Err(e) = vm.interpret("wrun/process", stdlib_src.process) {
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

    stdlib::args::set_args(cli.args.clone());

    if let Err(e) = vm.interpret("main", &source) {
        eprintln!("{}", e);
        return ExitCode::FAILURE;
    }

    ExitCode::SUCCESS
}
