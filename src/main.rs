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
    /// Evaluate Wren code directly instead of reading from a file
    #[arg(short = 'e', long = "eval", value_name = "CODE")]
    eval: Option<String>,

    /// The Wren script to execute
    #[arg(required_unless_present = "eval")]
    script: Option<PathBuf>,

    /// Arguments to pass to the script
    #[arg(trailing_var_arg = true)]
    args: Vec<String>,
}

fn main() -> ExitCode {
    let cli = Cli::parse();

    let source = if let Some(eval_code) = &cli.eval {
        eval_code.clone()
    } else {
        let script_path = cli.script.as_ref().unwrap();
        match std::fs::read_to_string(script_path) {
            Ok(s) => s,
            Err(e) => {
                eprintln!("Error reading script '{}': {}", script_path.display(), e);
                return ExitCode::FAILURE;
            }
        }
    };

    let script_dir = cli
        .script
        .as_ref()
        .and_then(|p| p.parent())
        .map(|p| p.to_path_buf())
        .unwrap_or_else(|| PathBuf::from("."));

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
    if let Err(e) = vm.interpret("wrun/str", stdlib_src.str) {
        eprintln!("{}", e);
        return ExitCode::FAILURE;
    }
    if let Err(e) = vm.interpret("wrun/print", stdlib_src.print) {
        eprintln!("{}", e);
        return ExitCode::FAILURE;
    }

    stdlib::args::set_args(cli.args.clone());
    stdlib::print::set_script_dir(script_dir.to_string_lossy().to_string());

    if let Err(e) = vm.interpret("main", &source) {
        eprintln!("{}", e);
        return ExitCode::FAILURE;
    }

    ExitCode::SUCCESS
}
