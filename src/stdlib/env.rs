use ruwren::foreign_v2::WrenString;
use ruwren::{wren_impl, ModuleLibrary, WrenObject};
use std::env;

#[derive(WrenObject, Default)]
pub struct Env;

#[wren_impl]
impl Env {
    fn get(&self, key: WrenString) -> String {
        let key = key.into_string().unwrap_or_default();
        env::var(&key).unwrap_or_default()
    }

    fn set(&self, key: WrenString, value: WrenString) {
        let key = key.into_string().unwrap_or_default();
        let value = value.into_string().unwrap_or_default();
        unsafe {
            env::set_var(&key, &value);
        }
        // env::set_var(&key, &value);
    }

    fn remove(&self, key: WrenString) {
        let key = key.into_string().unwrap_or_default();
        unsafe {
            env::remove_var(&key);
        }
        // env::remove_var(&key);
    }

    fn has(&self, key: WrenString) -> bool {
        let key = key.into_string().unwrap_or_default();
        env::var(&key).is_ok()
    }

    fn all(&self) -> Vec<String> {
        env::vars().map(|(k, v)| format!("{}={}", k, v)).collect()
    }

    fn keys(&self) -> Vec<String> {
        env::vars().map(|(k, _)| k).collect()
    }

    fn home(&self) -> String {
        env::var("HOME")
            .or_else(|_| env::var("USERPROFILE"))
            .unwrap_or_default()
    }

    fn user(&self) -> String {
        env::var("USER")
            .or_else(|_| env::var("USERNAME"))
            .unwrap_or_default()
    }

    fn os(&self) -> String {
        env::consts::OS.to_string()
    }

    fn arch(&self) -> String {
        env::consts::ARCH.to_string()
    }
}

ruwren::wren_module! {
    mod wrun_env {
        pub crate::stdlib::env::Env;
    }
}

pub fn publish_module(lib: &mut ModuleLibrary) {
    wrun_env::publish_module(lib);
}
