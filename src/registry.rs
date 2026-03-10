use chrono::Utc;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::BTreeMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};
use thiserror::Error;

const REGISTRY_SCHEMA_VERSION: u32 = 1;

#[derive(Debug, Error)]
pub enum RegistryError {
    #[error("could not determine user home directory (HOME/USERPROFILE not set)")]
    HomeNotFound,
    #[error("invalid script name '{0}' (allowed: letters, numbers, '.', '-', '_')")]
    InvalidName(String),
    #[error("script '{0}' is already installed (use --force to replace)")]
    AlreadyInstalled(String),
    #[error("script '{0}' is not installed")]
    NotInstalled(String),
    #[error("source file has no valid file stem: {0}")]
    InvalidSourceName(String),
    #[error("unsupported registry schema version: {0}")]
    UnsupportedSchema(u32),
    #[error(transparent)]
    Io(#[from] std::io::Error),
    #[error(transparent)]
    Json(#[from] serde_json::Error),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegistryEntry {
    pub name: String,
    pub script_path: String,
    pub source_path: String,
    pub installed_at: String,
    pub sha256: String,
}

#[derive(Debug, Clone)]
pub struct InstallResult {
    pub entry: RegistryEntry,
    pub shim_path: Option<PathBuf>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct RegistryIndex {
    schema_version: u32,
    entries: BTreeMap<String, RegistryEntry>,
}

impl Default for RegistryIndex {
    fn default() -> Self {
        Self {
            schema_version: REGISTRY_SCHEMA_VERSION,
            entries: BTreeMap::new(),
        }
    }
}

#[derive(Debug, Clone)]
pub struct Registry {
    registry_dir: PathBuf,
    scripts_dir: PathBuf,
    bin_dir: PathBuf,
    index_path: PathBuf,
}

impl Registry {
    pub fn new() -> Result<Self, RegistryError> {
        let home = env::var_os("HOME")
            .or_else(|| env::var_os("USERPROFILE"))
            .map(PathBuf::from)
            .ok_or(RegistryError::HomeNotFound)?;
        let root_dir = home.join(".wrun");
        let registry_dir = root_dir.join("registry");
        let scripts_dir = registry_dir.join("scripts");
        let bin_dir = root_dir.join("bin");
        let index_path = registry_dir.join("index.json");
        Ok(Self {
            registry_dir,
            scripts_dir,
            bin_dir,
            index_path,
        })
    }
    pub fn bin_dir(&self) -> &Path {
        &self.bin_dir
    }

    pub fn install(
        &self,
        source: &Path,
        requested_name: Option<&str>,
        force: bool,
        create_shim: bool,
    ) -> Result<InstallResult, RegistryError> {
        self.ensure_layout()?;
        let source_path = fs::canonicalize(source)?;
        let source_contents = fs::read_to_string(&source_path)?;
        let name = self.resolve_name(&source_path, requested_name)?;

        let mut index = self.load_index()?;
        if index.entries.contains_key(&name) && !force {
            return Err(RegistryError::AlreadyInstalled(name));
        }

        let script_path = self.script_path_for(&name);
        if let Some(parent) = script_path.parent() {
            fs::create_dir_all(parent)?;
        }
        fs::write(&script_path, &source_contents)?;

        let sha256 = format!("{:x}", Sha256::digest(source_contents.as_bytes()));
        let entry = RegistryEntry {
            name: name.clone(),
            script_path: script_path.to_string_lossy().to_string(),
            source_path: source_path.to_string_lossy().to_string(),
            installed_at: Utc::now().to_rfc3339(),
            sha256,
        };
        index.entries.insert(name.clone(), entry.clone());
        self.save_index(&index)?;

        let shim_path = if create_shim {
            Some(self.create_shim(&name)?)
        } else {
            None
        };

        Ok(InstallResult { entry, shim_path })
    }

    pub fn uninstall(&self, name: &str) -> Result<(), RegistryError> {
        if !is_valid_name(name) {
            return Err(RegistryError::InvalidName(name.to_string()));
        }
        self.ensure_layout()?;
        let mut index = self.load_index()?;
        if index.entries.remove(name).is_none() {
            return Err(RegistryError::NotInstalled(name.to_string()));
        }
        self.save_index(&index)?;

        let script_dir = self.scripts_dir.join(name);
        if script_dir.exists() {
            fs::remove_dir_all(script_dir)?;
        }
        self.remove_shim(name)?;
        Ok(())
    }

    pub fn get(&self, name: &str) -> Result<Option<RegistryEntry>, RegistryError> {
        if !is_valid_name(name) {
            return Err(RegistryError::InvalidName(name.to_string()));
        }
        let index = self.load_index()?;
        Ok(index.entries.get(name).cloned())
    }

    pub fn list(&self) -> Result<Vec<RegistryEntry>, RegistryError> {
        let index = self.load_index()?;
        Ok(index.entries.values().cloned().collect())
    }

    pub fn is_bin_on_path(&self) -> bool {
        let path_var = match env::var_os("PATH") {
            Some(v) => v,
            None => return false,
        };
        let target = canonical_or_self(&self.bin_dir);
        env::split_paths(&path_var).any(|p| canonical_or_self(&p) == target)
    }

    pub fn path_hint(&self) -> String {
        if cfg!(windows) {
            return "setx PATH \"%USERPROFILE%\\.wrun\\bin;%PATH%\"".to_string();
        }

        let shell = env::var("SHELL").unwrap_or_default();
        if shell.contains("fish") {
            format!("set -Ux PATH \"{}\" $PATH", self.bin_dir.display())
        } else {
            "export PATH=\"$HOME/.wrun/bin:$PATH\"".to_string()
        }
    }

    fn ensure_layout(&self) -> Result<(), RegistryError> {
        fs::create_dir_all(&self.registry_dir)?;
        fs::create_dir_all(&self.scripts_dir)?;
        fs::create_dir_all(&self.bin_dir)?;
        Ok(())
    }

    fn resolve_name(
        &self,
        source_path: &Path,
        requested_name: Option<&str>,
    ) -> Result<String, RegistryError> {
        let name = match requested_name {
            Some(raw) => raw.trim().to_string(),
            None => source_path
                .file_stem()
                .and_then(|s| s.to_str())
                .map(|s| s.to_string())
                .ok_or_else(|| {
                    RegistryError::InvalidSourceName(source_path.to_string_lossy().to_string())
                })?,
        };
        if !is_valid_name(&name) {
            return Err(RegistryError::InvalidName(name));
        }
        Ok(name)
    }

    fn script_path_for(&self, name: &str) -> PathBuf {
        self.scripts_dir.join(name).join("script.wren")
    }

    fn load_index(&self) -> Result<RegistryIndex, RegistryError> {
        if !self.index_path.exists() {
            return Ok(RegistryIndex::default());
        }
        let text = fs::read_to_string(&self.index_path)?;
        let index: RegistryIndex = serde_json::from_str(&text)?;
        if index.schema_version != REGISTRY_SCHEMA_VERSION {
            return Err(RegistryError::UnsupportedSchema(index.schema_version));
        }
        Ok(index)
    }

    fn save_index(&self, index: &RegistryIndex) -> Result<(), RegistryError> {
        self.ensure_layout()?;
        let json = serde_json::to_string_pretty(index)?;
        self.write_atomic(&self.index_path, json.as_bytes())
    }

    fn write_atomic(&self, path: &Path, bytes: &[u8]) -> Result<(), RegistryError> {
        let parent = path
            .parent()
            .ok_or_else(|| std::io::Error::other("path has no parent"))?;
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_nanos();
        let tmp_path = parent.join(format!(".index.json.tmp.{}.{}", std::process::id(), nanos));
        fs::write(&tmp_path, bytes)?;

        #[cfg(windows)]
        {
            if path.exists() {
                fs::remove_file(path)?;
            }
        }

        fs::rename(&tmp_path, path)?;
        Ok(())
    }

    fn create_shim(&self, name: &str) -> Result<PathBuf, RegistryError> {
        fs::create_dir_all(&self.bin_dir)?;

        #[cfg(windows)]
        {
            let shim_path = self.bin_dir.join(format!("{}.cmd", name));
            let content = format!("@echo off\r\nwrun \"{}\" %*\r\n", name);
            fs::write(&shim_path, content)?;
            return Ok(shim_path);
        }

        #[cfg(not(windows))]
        {
            let shim_path = self.bin_dir.join(name);
            let content = format!("#!/usr/bin/env sh\nexec wrun \"{}\" \"$@\"\n", name);
            fs::write(&shim_path, content)?;
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                let mut perms = fs::metadata(&shim_path)?.permissions();
                perms.set_mode(0o755);
                fs::set_permissions(&shim_path, perms)?;
            }
            Ok(shim_path)
        }
    }

    fn remove_shim(&self, name: &str) -> Result<(), RegistryError> {
        let unix_shim = self.bin_dir.join(name);
        if unix_shim.exists() {
            fs::remove_file(unix_shim)?;
        }

        let windows_shim = self.bin_dir.join(format!("{}.cmd", name));
        if windows_shim.exists() {
            fs::remove_file(windows_shim)?;
        }
        Ok(())
    }
}

fn is_valid_name(name: &str) -> bool {
    !name.is_empty()
        && name
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || c == '.' || c == '-' || c == '_')
}

fn canonical_or_self(path: &Path) -> PathBuf {
    fs::canonicalize(path).unwrap_or_else(|_| path.to_path_buf())
}
