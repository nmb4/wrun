#![allow(non_snake_case)]

use chrono::Local;
use ruwren::foreign_v2::WrenString;
use ruwren::{ModuleLibrary, WrenObject, wren_impl};
use std::fs::OpenOptions;
use std::io::Write;
use std::sync::RwLock;

// ANSI color codes using standard 16-color palette
const RESET: &str = "\x1b[0m";

// Standard ANSI foreground colors (3X = normal, 9X = bright)
const FG_BLACK: &str = "\x1b[30m";
const FG_RED: &str = "\x1b[31m";
const FG_GREEN: &str = "\x1b[32m";
const FG_YELLOW: &str = "\x1b[33m";
const FG_BLUE: &str = "\x1b[34m";
const FG_MAGENTA: &str = "\x1b[35m";
const FG_CYAN: &str = "\x1b[36m";
const FG_WHITE: &str = "\x1b[37m";
const FG_BRIGHT_BLACK: &str = "\x1b[90m"; // gray
const FG_BRIGHT_RED: &str = "\x1b[91m";
const FG_BRIGHT_GREEN: &str = "\x1b[92m";
const FG_BRIGHT_YELLOW: &str = "\x1b[93m";
const FG_BRIGHT_BLUE: &str = "\x1b[94m";
const FG_BRIGHT_MAGENTA: &str = "\x1b[95m";
const FG_BRIGHT_CYAN: &str = "\x1b[96m";
const FG_BRIGHT_WHITE: &str = "\x1b[97m";

fn badge(level: u8, level_name: &str, custom_accent: Option<&str>) -> String {
    let bg = bg_code(level);
    // Format: [reset;accent]▌ + [black;bg;bold] LEVEL [reset] + space
    // Matches: \033[0;32m▌\033[0;30;42;1m INFO \033[0;39m
    format!(
        "\x1b[0;{}m▌\x1b[0;30;{};1m {} \x1b[0;39m ",
        fg_code(level, custom_accent),
        bg,
        level_name
    )
}

fn fg_code(level: u8, custom_accent: Option<&str>) -> u8 {
    if custom_accent.is_some() {
        // Custom levels default to green
        32
    } else {
        match level {
            0 => 90, // TRACE - bright black (gray)
            1 => 34, // DEBUG - blue
            2 => 32, // INFO - green
            3 => 33, // WARN - yellow
            4 => 31, // ERROR - red
            _ => 32, // CUSTOM - green
        }
    }
}

fn bg_code(level: u8) -> u8 {
    match level {
        0 => 100, // TRACE - bright black (visible gray)
        1 => 44,  // DEBUG - blue
        2 => 42,  // INFO - green
        3 => 43,  // WARN - yellow
        4 => 41,  // ERROR - red
        _ => 42,  // CUSTOM - green
    }
}

fn ansi_color(name: &str) -> &'static str {
    match name.to_lowercase().as_str() {
        "black" => FG_BLACK,
        "red" => FG_RED,
        "green" => FG_GREEN,
        "yellow" => FG_YELLOW,
        "blue" => FG_BLUE,
        "magenta" => FG_MAGENTA,
        "cyan" => FG_CYAN,
        "white" => FG_WHITE,
        "gray" | "grey" => FG_BRIGHT_BLACK,
        "bright_black" => FG_BRIGHT_BLACK,
        "bright_red" => FG_BRIGHT_RED,
        "bright_green" => FG_BRIGHT_GREEN,
        "bright_yellow" => FG_BRIGHT_YELLOW,
        "bright_blue" => FG_BRIGHT_BLUE,
        "bright_magenta" => FG_BRIGHT_MAGENTA,
        "bright_cyan" => FG_BRIGHT_CYAN,
        "bright_white" => FG_BRIGHT_WHITE,
        _ => FG_WHITE,
    }
}

// ============== Print Class ==============

#[derive(WrenObject, Default)]
pub struct Print;

#[wren_impl]
impl Print {
    fn eprint(&self, msg: WrenString) {
        let msg = msg.into_string().unwrap_or_default();
        eprintln!("{}", msg);
    }

    fn cprint(&self, msg: WrenString) {
        let msg = msg.into_string().unwrap_or_default();
        println!("{}{}{}", FG_GREEN, msg, RESET);
    }

    fn cprintColor(&self, msg: WrenString, color: WrenString) {
        let msg = msg.into_string().unwrap_or_default();
        let color_name = color.into_string().unwrap_or_default();
        let color_code = ansi_color(&color_name);
        println!("{}{}{}", color_code, msg, RESET);
    }
}

// ============== Log Configuration ==============

#[derive(Clone)]
struct CustomLevel {
    name: String,
    color: &'static str,
    priority: u8, // 0=TRACE, 1=DEBUG, 2=INFO, 3=WARN, 4=ERROR, 5+=custom
}

struct LogConfig {
    script_dir: Option<String>,
    file_path: Option<String>,
    terminal_level: u8, // minimum level for terminal (default: INFO=2)
    file_level: u8,     // minimum level for file (default: DEBUG=1)
    custom_levels: Vec<CustomLevel>,
}

impl Default for LogConfig {
    fn default() -> Self {
        Self {
            script_dir: None,
            file_path: None,
            terminal_level: 2, // INFO
            file_level: 1,     // DEBUG
            custom_levels: Vec::new(),
        }
    }
}

static LOG_CONFIG: RwLock<LogConfig> = RwLock::new(LogConfig {
    script_dir: None,
    file_path: None,
    terminal_level: 2,
    file_level: 1,
    custom_levels: Vec::new(),
});

pub fn set_script_dir(dir: String) {
    if let Ok(mut config) = LOG_CONFIG.write() {
        config.script_dir = Some(dir);
    }
}

fn get_log_file_path() -> Option<String> {
    if let Ok(config) = LOG_CONFIG.read() {
        if let Some(ref path) = config.file_path {
            return Some(path.clone());
        }
        if let Some(ref dir) = config.script_dir {
            return Some(format!("{}/wrun.log", dir));
        }
    }
    None
}

fn level_name_to_num(name: &str) -> u8 {
    match name.to_lowercase().as_str() {
        "trace" => 0,
        "debug" => 1,
        "info" => 2,
        "warn" | "warning" => 3,
        "error" => 4,
        _ => 5, // custom levels are above error by default
    }
}

fn level_name(level: u8) -> &'static str {
    match level {
        0 => "TRACE",
        1 => "DEBUG",
        2 => " INFO", // padded to 5 chars
        3 => " WARN", // padded to 5 chars
        4 => "ERROR",
        _ => "CUSTOM",
    }
}

fn should_log_terminal(level: u8) -> bool {
    if let Ok(config) = LOG_CONFIG.read() {
        level >= config.terminal_level
    } else {
        true
    }
}

fn should_log_file(level: u8) -> bool {
    if let Ok(config) = LOG_CONFIG.read() {
        level >= config.file_level
    } else {
        true
    }
}

fn format_kv(kv_str: &str, fg: u8) -> String {
    if kv_str.is_empty() {
        return String::new();
    }
    let pairs: Vec<&str> = kv_str.split('\x00').collect();
    let formatted: Vec<String> = pairs
        .iter()
        .filter(|p| !p.is_empty())
        .map(|p| {
            // Split on first '=' to separate key and value
            if let Some(eq_pos) = p.find('=') {
                let key = &p[..eq_pos];
                let value = &p[eq_pos + 1..];
                // key= is dimmed, value is accent color
                format!("\x1b[0;39;2m{}=\x1b[0;{}m{}{}", key, fg, value, RESET)
            } else {
                // No '=' found, just dim the whole thing
                format!("\x1b[0;39;2m{}{}", p, RESET)
            }
        })
        .collect();
    if formatted.is_empty() {
        String::new()
    } else {
        format!(" {}", formatted.join(" "))
    }
}

fn format_kv_plain(kv_str: &str) -> String {
    if kv_str.is_empty() {
        return String::new();
    }
    let pairs: Vec<&str> = kv_str.split('\x00').collect();
    let formatted: Vec<&str> = pairs.iter().filter(|p| !p.is_empty()).copied().collect();
    if formatted.is_empty() {
        String::new()
    } else {
        format!(" {}", formatted.join(" "))
    }
}

fn log_message(level: u8, level_str: &str, msg: &str, kv_str: &str, custom_accent: Option<&str>) {
    let time_terminal = Local::now().format("%H:%M").to_string();
    let time_file = Local::now().format("%H:%M %d-%m-%y").to_string();

    // Terminal output format: ▌ LEVEL  HH:MM(dim)  message
    // Matches: \033[0;32m▌\033[0;30;42;1m INFO \033[0;39m \033[0;39;2m17:34\033[0;39m  add lol.rs\033[0;32m\n
    if should_log_terminal(level) {
        let badge_str = badge(level, level_str, custom_accent);
        let fg = fg_code(level, custom_accent);
        let kv_formatted = format_kv(kv_str, fg);
        // Time is dimmed, then reset, then message, then accent color for newline
        println!(
            "{}\x1b[0;39;2m{}\x1b[0;39m  {}{}\x1b[0;{}m",
            badge_str, time_terminal, msg, kv_formatted, fg
        );
    }

    // File output (unchanged format): HH:MM DD-MM-YY LEVEL message
    if should_log_file(level) {
        if let Some(file_path) = get_log_file_path() {
            let kv_formatted = format_kv_plain(kv_str);
            let line = format!("{} {} {}{}\n", time_file, level_str, msg, kv_formatted);
            if let Ok(mut file) = OpenOptions::new()
                .create(true)
                .append(true)
                .open(&file_path)
            {
                let _ = file.write_all(line.as_bytes());
            }
        }
    }
}

fn find_custom_level(name: &str) -> Option<CustomLevel> {
    if let Ok(config) = LOG_CONFIG.read() {
        config
            .custom_levels
            .iter()
            .find(|l| l.name.eq_ignore_ascii_case(name))
            .cloned()
    } else {
        None
    }
}

// ============== Log Class ==============

#[derive(WrenObject, Default)]
pub struct LogInternal;

#[wren_impl]
impl LogInternal {
    // Level methods
    fn trace(&self, msg: WrenString) {
        let msg = msg.into_string().unwrap_or_default();
        log_message(0, level_name(0), &msg, "", None);
    }

    fn traceKv(&self, msg: WrenString, kv: WrenString) {
        let msg = msg.into_string().unwrap_or_default();
        let kv = kv.into_string().unwrap_or_default();
        log_message(0, level_name(0), &msg, &kv, None);
    }

    fn debug(&self, msg: WrenString) {
        let msg = msg.into_string().unwrap_or_default();
        log_message(1, level_name(1), &msg, "", None);
    }

    fn debugKv(&self, msg: WrenString, kv: WrenString) {
        let msg = msg.into_string().unwrap_or_default();
        let kv = kv.into_string().unwrap_or_default();
        log_message(1, level_name(1), &msg, &kv, None);
    }

    fn info(&self, msg: WrenString) {
        let msg = msg.into_string().unwrap_or_default();
        log_message(2, level_name(2), &msg, "", None);
    }

    fn infoKv(&self, msg: WrenString, kv: WrenString) {
        let msg = msg.into_string().unwrap_or_default();
        let kv = kv.into_string().unwrap_or_default();
        log_message(2, level_name(2), &msg, &kv, None);
    }

    fn warn(&self, msg: WrenString) {
        let msg = msg.into_string().unwrap_or_default();
        log_message(3, level_name(3), &msg, "", None);
    }

    fn warnKv(&self, msg: WrenString, kv: WrenString) {
        let msg = msg.into_string().unwrap_or_default();
        let kv = kv.into_string().unwrap_or_default();
        log_message(3, level_name(3), &msg, &kv, None);
    }

    fn error(&self, msg: WrenString) {
        let msg = msg.into_string().unwrap_or_default();
        log_message(4, level_name(4), &msg, "", None);
    }

    fn errorKv(&self, msg: WrenString, kv: WrenString) {
        let msg = msg.into_string().unwrap_or_default();
        let kv = kv.into_string().unwrap_or_default();
        log_message(4, level_name(4), &msg, &kv, None);
    }

    fn custom(&self, level_name_str: WrenString, msg: WrenString) {
        let level_name_str = level_name_str.into_string().unwrap_or_default();
        let msg = msg.into_string().unwrap_or_default();

        if let Some(custom) = find_custom_level(&level_name_str) {
            let padded_name = format!("{:>5}", custom.name.to_uppercase());
            log_message(custom.priority, &padded_name, &msg, "", Some(custom.color));
        } else {
            // Fallback: treat as custom above error
            let padded_name = format!("{:>5}", level_name_str.to_uppercase());
            log_message(5, &padded_name, &msg, "", None);
        }
    }

    fn customKv(&self, level_name_str: WrenString, msg: WrenString, kv: WrenString) {
        let level_name_str = level_name_str.into_string().unwrap_or_default();
        let msg = msg.into_string().unwrap_or_default();
        let kv = kv.into_string().unwrap_or_default();

        if let Some(custom) = find_custom_level(&level_name_str) {
            let padded_name = format!("{:>5}", custom.name.to_uppercase());
            log_message(custom.priority, &padded_name, &msg, &kv, Some(custom.color));
        } else {
            let padded_name = format!("{:>5}", level_name_str.to_uppercase());
            log_message(5, &padded_name, &msg, &kv, None);
        }
    }

    // Configuration
    fn setFile(&self, path: WrenString) {
        let path = path.into_string().unwrap_or_default();
        if let Ok(mut config) = LOG_CONFIG.write() {
            config.file_path = Some(path);
        }
    }

    fn setTerminalLevel(&self, level: WrenString) {
        let level = level.into_string().unwrap_or_default();
        let level_num = level_name_to_num(&level);
        if let Ok(mut config) = LOG_CONFIG.write() {
            config.terminal_level = level_num;
        }
    }

    fn setFileLevel(&self, level: WrenString) {
        let level = level.into_string().unwrap_or_default();
        let level_num = level_name_to_num(&level);
        if let Ok(mut config) = LOG_CONFIG.write() {
            config.file_level = level_num;
        }
    }

    fn addLevel(&self, name: WrenString, color: WrenString, base_level: WrenString) {
        let name = name.into_string().unwrap_or_default();
        let color_name = color.into_string().unwrap_or_default();
        let base = base_level.into_string().unwrap_or_default();

        let color_code = ansi_color(&color_name);

        let priority = if base.is_empty() {
            5 // above error, always prints
        } else {
            level_name_to_num(&base)
        };

        let custom = CustomLevel {
            name,
            color: color_code,
            priority,
        };

        if let Ok(mut config) = LOG_CONFIG.write() {
            // Remove existing with same name
            config
                .custom_levels
                .retain(|l| !l.name.eq_ignore_ascii_case(&custom.name));
            config.custom_levels.push(custom);
        }
    }
}

ruwren::wren_module! {
    mod wrun_print {
        pub crate::stdlib::print::Print;
        pub crate::stdlib::print::LogInternal;
    }
}

pub fn publish_module(lib: &mut ModuleLibrary) {
    wrun_print::publish_module(lib);
}
