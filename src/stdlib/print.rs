#![allow(non_snake_case)]

use chrono::Local;
use ruwren::foreign_v2::WrenString;
use ruwren::{ModuleLibrary, WrenObject, wren_impl};
use std::fs::OpenOptions;
use std::io::Write;
use std::sync::RwLock;

// ANSI color codes using standard 16-color palette
const RESET: &str = "\x1b[0m";
const BOLD_DIM: &str = "\x1b[2m"; // dimmed text

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

// Standard ANSI background colors (4X = normal, 10X = bright)
const BG_GRAY: &str = "\x1b[40m"; // dark gray for TRACE
const BG_BLUE: &str = "\x1b[44m"; // blue for DEBUG
const BG_GREEN: &str = "\x1b[42m"; // green for INFO
const BG_YELLOW: &str = "\x1b[43m"; // yellow for WARN
const BG_RED: &str = "\x1b[41m"; // red for ERROR

fn badge(level_bg: &str, level_name: &str, level_fg: &str) -> String {
    // Background + foreground + bold (2) + text + reset
    format!(
        "{}{}{}\x1b[39;1m {} \x1b[0m",
        level_bg, level_fg, BOLD_DIM, level_name
    )
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

fn level_bg(level: u8) -> &'static str {
    match level {
        0 => BG_GRAY,   // TRACE - gray
        1 => BG_BLUE,   // DEBUG - blue
        2 => BG_GREEN,  // INFO - green
        3 => BG_YELLOW, // WARN - yellow
        4 => BG_RED,    // ERROR - red
        _ => BG_GREEN,  // CUSTOM - green
    }
}

fn level_fg(level: u8) -> &'static str {
    match level {
        0 => FG_BLACK, // TRACE - black on gray
        1 => FG_BLACK, // DEBUG - black on blue
        2 => FG_BLACK, // INFO - black on green
        3 => FG_BLACK, // WARN - black on yellow
        4 => FG_BLACK, // ERROR - black on red
        _ => FG_BLACK, // CUSTOM - black on green
    }
}

fn level_name(level: u8) -> &'static str {
    match level {
        0 => "TRACE",
        1 => "DEBUG",
        2 => "INFO",
        3 => "WARN",
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

fn format_kv(kv_str: &str) -> String {
    if kv_str.is_empty() {
        return String::new();
    }
    let pairs: Vec<&str> = kv_str.split('\x00').collect();
    let formatted: Vec<String> = pairs
        .iter()
        .filter(|p| !p.is_empty())
        .map(|p| format!("{}{}{}", FG_CYAN, p, RESET))
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

fn log_message(level: u8, level_str: &str, msg: &str, kv_str: &str, level_bg_color: &str) {
    let time_terminal = Local::now().format("%H:%M").to_string();
    let time_file = Local::now().format("%H:%M %d-%m-%y").to_string();

    // Terminal output with badge format: | LEVEL | HH:MM   message
    if should_log_terminal(level) {
        let fg = level_fg(level);
        let badge_str = badge(level_bg_color, level_str, fg);
        let kv_formatted = format_kv(kv_str);
        println!("{} {}   {}{}", badge_str, time_terminal, msg, kv_formatted);
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
        log_message(0, level_name(0), &msg, "", level_bg(0));
    }

    fn traceKv(&self, msg: WrenString, kv: WrenString) {
        let msg = msg.into_string().unwrap_or_default();
        let kv = kv.into_string().unwrap_or_default();
        log_message(0, level_name(0), &msg, &kv, level_bg(0));
    }

    fn debug(&self, msg: WrenString) {
        let msg = msg.into_string().unwrap_or_default();
        log_message(1, level_name(1), &msg, "", level_bg(1));
    }

    fn debugKv(&self, msg: WrenString, kv: WrenString) {
        let msg = msg.into_string().unwrap_or_default();
        let kv = kv.into_string().unwrap_or_default();
        log_message(1, level_name(1), &msg, &kv, level_bg(1));
    }

    fn info(&self, msg: WrenString) {
        let msg = msg.into_string().unwrap_or_default();
        log_message(2, level_name(2), &msg, "", level_bg(2));
    }

    fn infoKv(&self, msg: WrenString, kv: WrenString) {
        let msg = msg.into_string().unwrap_or_default();
        let kv = kv.into_string().unwrap_or_default();
        log_message(2, level_name(2), &msg, &kv, level_bg(2));
    }

    fn warn(&self, msg: WrenString) {
        let msg = msg.into_string().unwrap_or_default();
        log_message(3, level_name(3), &msg, "", level_bg(3));
    }

    fn warnKv(&self, msg: WrenString, kv: WrenString) {
        let msg = msg.into_string().unwrap_or_default();
        let kv = kv.into_string().unwrap_or_default();
        log_message(3, level_name(3), &msg, &kv, level_bg(3));
    }

    fn error(&self, msg: WrenString) {
        let msg = msg.into_string().unwrap_or_default();
        log_message(4, level_name(4), &msg, "", level_bg(4));
    }

    fn errorKv(&self, msg: WrenString, kv: WrenString) {
        let msg = msg.into_string().unwrap_or_default();
        let kv = kv.into_string().unwrap_or_default();
        log_message(4, level_name(4), &msg, &kv, level_bg(4));
    }

    fn custom(&self, level_name_str: WrenString, msg: WrenString) {
        let level_name_str = level_name_str.into_string().unwrap_or_default();
        let msg = msg.into_string().unwrap_or_default();

        if let Some(custom) = find_custom_level(&level_name_str) {
            let padded_name = format!("{:>5}", custom.name.to_uppercase());
            log_message(custom.priority, &padded_name, &msg, "", custom.color);
        } else {
            // Fallback: treat as custom above error
            let padded_name = format!("{:>5}", level_name_str.to_uppercase());
            log_message(5, &padded_name, &msg, "", FG_GREEN);
        }
    }

    fn customKv(&self, level_name_str: WrenString, msg: WrenString, kv: WrenString) {
        let level_name_str = level_name_str.into_string().unwrap_or_default();
        let msg = msg.into_string().unwrap_or_default();
        let kv = kv.into_string().unwrap_or_default();

        if let Some(custom) = find_custom_level(&level_name_str) {
            let padded_name = format!("{:>5}", custom.name.to_uppercase());
            log_message(custom.priority, &padded_name, &msg, &kv, custom.color);
        } else {
            let padded_name = format!("{:>5}", level_name_str.to_uppercase());
            log_message(5, &padded_name, &msg, &kv, FG_GREEN);
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
