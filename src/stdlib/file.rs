#![allow(non_snake_case)]

use ruwren::foreign_v2::WrenString;
use ruwren::{ModuleLibrary, WrenObject, wren_impl};
use std::fs;
use std::path::Path;

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

ruwren::wren_module! {
    mod wrun_file {
        pub crate::stdlib::file::File;
        pub crate::stdlib::file::Dir;
        pub crate::stdlib::file::PathUtil;
    }
}

pub fn publish_module(lib: &mut ModuleLibrary) {
    wrun_file::publish_module(lib);
}
