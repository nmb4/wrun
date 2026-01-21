pub mod args;
mod env;
mod file;
pub mod print;
pub mod process;
mod str;

use ruwren::ModuleLibrary;

pub struct StdlibSource {
    pub process: &'static str,
    pub file: &'static str,
    pub env: &'static str,
    pub args: &'static str,
    pub str: &'static str,
    pub print: &'static str,
    pub pipeline: &'static str,
}

pub fn get_stdlib_source() -> StdlibSource {
    StdlibSource {
        process: include_str!("wren/process.wren"),
        file: include_str!("wren/file.wren"),
        env: include_str!("wren/env.wren"),
        args: include_str!("wren/args.wren"),
        str: include_str!("wren/str.wren"),
        print: include_str!("wren/print.wren"),
        pipeline: include_str!("wren/pipeline.wren"),
    }
}

pub fn publish_modules(lib: &mut ModuleLibrary) {
    process::publish_module(lib);
    file::publish_module(lib);
    env::publish_module(lib);
    args::publish_module(lib);
    str::publish_module(lib);
    print::publish_module(lib);
}
