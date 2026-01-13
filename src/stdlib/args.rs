use ruwren::{ModuleLibrary, WrenObject, wren_impl};
use std::sync::RwLock;

static ARGS: RwLock<Vec<String>> = RwLock::new(Vec::new());

pub fn set_args(args: Vec<String>) {
    if let Ok(mut guard) = ARGS.write() {
        *guard = args;
    }
}

fn get_args() -> Vec<String> {
    ARGS.read().map(|g| g.clone()).unwrap_or_default()
}

#[derive(WrenObject, Default)]
pub struct Args;

#[wren_impl]
impl Args {
    fn all(&self) -> Vec<String> {
        get_args()
    }

    fn count(&self) -> f64 {
        get_args().len() as f64
    }

    fn get(&self, index: f64) -> String {
        let args = get_args();
        let idx = index as usize;
        args.get(idx).cloned().unwrap_or_default()
    }

    fn first(&self) -> String {
        get_args().first().cloned().unwrap_or_default()
    }

    fn last(&self) -> String {
        get_args().last().cloned().unwrap_or_default()
    }

    fn has(&self, index: f64) -> bool {
        let idx = index as usize;
        idx < get_args().len()
    }

    fn slice(&self, start: f64, end: f64) -> Vec<String> {
        let args = get_args();
        let s = (start as usize).min(args.len());
        let e = (end as usize).min(args.len());
        args[s..e].to_vec()
    }
}

ruwren::wren_module! {
    mod wrun_args {
        pub crate::stdlib::args::Args;
    }
}

pub fn publish_module(lib: &mut ModuleLibrary) {
    wrun_args::publish_module(lib);
}
