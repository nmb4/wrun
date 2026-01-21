#![allow(non_snake_case)]

use ruwren::foreign_v2::WrenString;
use ruwren::{wren_impl, ModuleLibrary, WrenObject};

#[derive(WrenObject, Default)]
pub struct Str;

#[wren_impl]
impl Str {
    // Validation methods
    fn isEmpty(&self, s: WrenString) -> bool {
        s.into_string().unwrap_or_default().is_empty()
    }

    fn isBlank(&self, s: WrenString) -> bool {
        s.into_string().unwrap_or_default().trim().is_empty()
    }

    fn isNumeric(&self, s: WrenString) -> bool {
        let s = s.into_string().unwrap_or_default();
        !s.is_empty() && s.chars().all(|c| c.is_ascii_digit())
    }

    fn isAlpha(&self, s: WrenString) -> bool {
        let s = s.into_string().unwrap_or_default();
        !s.is_empty() && s.chars().all(|c| c.is_ascii_alphabetic())
    }

    fn isAlphaNumeric(&self, s: WrenString) -> bool {
        let s = s.into_string().unwrap_or_default();
        !s.is_empty() && s.chars().all(|c| c.is_ascii_alphanumeric())
    }

    fn isUpper(&self, s: WrenString) -> bool {
        let s = s.into_string().unwrap_or_default();
        !s.is_empty() && s.chars().all(|c| !c.is_alphabetic() || c.is_uppercase())
    }

    fn isLower(&self, s: WrenString) -> bool {
        let s = s.into_string().unwrap_or_default();
        !s.is_empty() && s.chars().all(|c| !c.is_alphabetic() || c.is_lowercase())
    }

    // Transformation methods
    fn trim(&self, s: WrenString) -> String {
        s.into_string().unwrap_or_default().trim().to_string()
    }

    fn trimStart(&self, s: WrenString) -> String {
        s.into_string().unwrap_or_default().trim_start().to_string()
    }

    fn trimEnd(&self, s: WrenString) -> String {
        s.into_string().unwrap_or_default().trim_end().to_string()
    }

    fn toUpper(&self, s: WrenString) -> String {
        s.into_string().unwrap_or_default().to_uppercase()
    }

    fn toLower(&self, s: WrenString) -> String {
        s.into_string().unwrap_or_default().to_lowercase()
    }

    fn capitalize(&self, s: WrenString) -> String {
        let s = s.into_string().unwrap_or_default();
        let mut chars = s.chars();
        match chars.next() {
            None => String::new(),
            Some(first) => first.to_uppercase().to_string() + chars.as_str(),
        }
    }

    fn reverse(&self, s: WrenString) -> String {
        s.into_string().unwrap_or_default().chars().rev().collect()
    }

    fn repeat(&self, s: WrenString, count: f64) -> String {
        let s = s.into_string().unwrap_or_default();
        let count = count.max(0.0) as usize;
        s.repeat(count)
    }

    fn padStart(&self, s: WrenString, length: f64, pad: WrenString) -> String {
        let s = s.into_string().unwrap_or_default();
        let pad = pad.into_string().unwrap_or_else(|_| " ".to_string());
        let len = length.max(0.0) as usize;
        if s.len() >= len || pad.is_empty() {
            return s;
        }
        let pad_len = len - s.len();
        let mut result = String::new();
        while result.len() < pad_len {
            result.push_str(&pad);
        }
        result.truncate(pad_len);
        result.push_str(&s);
        result
    }

    fn padEnd(&self, s: WrenString, length: f64, pad: WrenString) -> String {
        let s = s.into_string().unwrap_or_default();
        let pad = pad.into_string().unwrap_or_else(|_| " ".to_string());
        let len = length.max(0.0) as usize;
        if s.len() >= len || pad.is_empty() {
            return s;
        }
        let mut result = s;
        while result.len() < len {
            result.push_str(&pad);
        }
        result.truncate(len);
        result
    }

    fn camelCase(&self, s: WrenString) -> String {
        let s = s.into_string().unwrap_or_default();
        let mut result = String::new();
        let mut capitalize_next = false;
        let mut first = true;

        for c in s.chars() {
            if c == '_' || c == '-' || c == ' ' {
                capitalize_next = true;
            } else if c.is_alphanumeric() {
                if first {
                    result.push(c.to_ascii_lowercase());
                    first = false;
                } else if capitalize_next {
                    result.push(c.to_ascii_uppercase());
                    capitalize_next = false;
                } else {
                    result.push(c.to_ascii_lowercase());
                }
            }
        }
        result
    }

    fn snakeCase(&self, s: WrenString) -> String {
        let s = s.into_string().unwrap_or_default();
        let mut result = String::new();
        let mut prev_was_lower = false;

        for c in s.chars() {
            if c == ' ' || c == '-' {
                if !result.is_empty() && !result.ends_with('_') {
                    result.push('_');
                }
                prev_was_lower = false;
            } else if c.is_uppercase() {
                if prev_was_lower {
                    result.push('_');
                }
                result.push(c.to_ascii_lowercase());
                prev_was_lower = false;
            } else if c.is_alphanumeric() {
                result.push(c);
                prev_was_lower = c.is_lowercase();
            }
        }
        result
    }

    fn kebabCase(&self, s: WrenString) -> String {
        let s = s.into_string().unwrap_or_default();
        let mut result = String::new();
        let mut prev_was_lower = false;

        for c in s.chars() {
            if c == ' ' || c == '_' {
                if !result.is_empty() && !result.ends_with('-') {
                    result.push('-');
                }
                prev_was_lower = false;
            } else if c.is_uppercase() {
                if prev_was_lower {
                    result.push('-');
                }
                result.push(c.to_ascii_lowercase());
                prev_was_lower = false;
            } else if c.is_alphanumeric() {
                result.push(c);
                prev_was_lower = c.is_lowercase();
            }
        }
        result
    }

    fn truncate(&self, s: WrenString, length: f64) -> String {
        let s = s.into_string().unwrap_or_default();
        let len = length.max(0.0) as usize;
        if s.chars().count() <= len {
            return s;
        }
        if len <= 3 {
            return s.chars().take(len).collect();
        }
        let mut result: String = s.chars().take(len - 3).collect();
        result.push_str("...");
        result
    }

    fn truncateWith(&self, s: WrenString, length: f64, ellipsis: WrenString) -> String {
        let s = s.into_string().unwrap_or_default();
        let ellipsis = ellipsis.into_string().unwrap_or_else(|_| "...".to_string());
        let len = length.max(0.0) as usize;
        let char_count = s.chars().count();
        if char_count <= len {
            return s;
        }
        let ellipsis_len = ellipsis.chars().count();
        if len <= ellipsis_len {
            return s.chars().take(len).collect();
        }
        let mut result: String = s.chars().take(len - ellipsis_len).collect();
        result.push_str(&ellipsis);
        result
    }

    fn replace(&self, s: WrenString, old: WrenString, new: WrenString) -> String {
        let s = s.into_string().unwrap_or_default();
        let old = old.into_string().unwrap_or_default();
        let new = new.into_string().unwrap_or_default();
        if let Some(idx) = s.find(&old) {
            let mut result = s[..idx].to_string();
            result.push_str(&new);
            result.push_str(&s[idx + old.len()..]);
            result
        } else {
            s
        }
    }

    fn replaceAll(&self, s: WrenString, old: WrenString, new: WrenString) -> String {
        let s = s.into_string().unwrap_or_default();
        let old = old.into_string().unwrap_or_default();
        let new = new.into_string().unwrap_or_default();
        s.replace(&old, &new)
    }

    // Search methods
    fn contains(&self, s: WrenString, sub: WrenString) -> bool {
        let s = s.into_string().unwrap_or_default();
        let sub = sub.into_string().unwrap_or_default();
        s.contains(&sub)
    }

    fn startsWith(&self, s: WrenString, prefix: WrenString) -> bool {
        let s = s.into_string().unwrap_or_default();
        let prefix = prefix.into_string().unwrap_or_default();
        s.starts_with(&prefix)
    }

    fn endsWith(&self, s: WrenString, suffix: WrenString) -> bool {
        let s = s.into_string().unwrap_or_default();
        let suffix = suffix.into_string().unwrap_or_default();
        s.ends_with(&suffix)
    }

    fn indexOf(&self, s: WrenString, sub: WrenString) -> f64 {
        let s = s.into_string().unwrap_or_default();
        let sub = sub.into_string().unwrap_or_default();
        s.find(&sub).map(|i| i as f64).unwrap_or(-1.0)
    }

    fn lastIndexOf(&self, s: WrenString, sub: WrenString) -> f64 {
        let s = s.into_string().unwrap_or_default();
        let sub = sub.into_string().unwrap_or_default();
        s.rfind(&sub).map(|i| i as f64).unwrap_or(-1.0)
    }

    fn count(&self, s: WrenString, sub: WrenString) -> f64 {
        let s = s.into_string().unwrap_or_default();
        let sub = sub.into_string().unwrap_or_default();
        if sub.is_empty() {
            return 0.0;
        }
        s.matches(&sub).count() as f64
    }

    // Split/join methods
    fn split(&self, s: WrenString, sep: WrenString) -> Vec<String> {
        let s = s.into_string().unwrap_or_default();
        let sep = sep.into_string().unwrap_or_default();
        if sep.is_empty() {
            return s.chars().map(|c| c.to_string()).collect();
        }
        s.split(&sep).map(|p| p.to_string()).collect()
    }

    fn splitLimit(&self, s: WrenString, sep: WrenString, limit: f64) -> Vec<String> {
        let s = s.into_string().unwrap_or_default();
        let sep = sep.into_string().unwrap_or_default();
        let limit = limit.max(1.0) as usize;
        if sep.is_empty() {
            return s.chars().take(limit).map(|c| c.to_string()).collect();
        }
        s.splitn(limit, &sep).map(|p| p.to_string()).collect()
    }

    fn lines(&self, s: WrenString) -> Vec<String> {
        let s = s.into_string().unwrap_or_default();
        s.lines().map(|l| l.to_string()).collect()
    }

    fn chars(&self, s: WrenString) -> Vec<String> {
        s.into_string()
            .unwrap_or_default()
            .chars()
            .map(|c| c.to_string())
            .collect()
    }

    fn words(&self, s: WrenString) -> Vec<String> {
        s.into_string()
            .unwrap_or_default()
            .split_whitespace()
            .map(|w| w.to_string())
            .collect()
    }

    // Slice methods
    fn slice(&self, s: WrenString, start: f64) -> String {
        let s = s.into_string().unwrap_or_default();
        let start = start.max(0.0) as usize;
        s.chars().skip(start).collect()
    }

    fn sliceRange(&self, s: WrenString, start: f64, end: f64) -> String {
        let s = s.into_string().unwrap_or_default();
        let start = start.max(0.0) as usize;
        let end = end.max(0.0) as usize;
        if start >= end {
            return String::new();
        }
        s.chars().skip(start).take(end - start).collect()
    }

    fn at(&self, s: WrenString, index: f64) -> String {
        let s = s.into_string().unwrap_or_default();
        let index = index as usize;
        s.chars()
            .nth(index)
            .map(|c| c.to_string())
            .unwrap_or_default()
    }

    // Length
    fn length(&self, s: WrenString) -> f64 {
        s.into_string().unwrap_or_default().chars().count() as f64
    }

    fn byteLength(&self, s: WrenString) -> f64 {
        s.into_string().unwrap_or_default().len() as f64
    }
}

ruwren::wren_module! {
    mod wrun_str {
        pub crate::stdlib::str::Str;
    }
}

pub fn publish_module(lib: &mut ModuleLibrary) {
    wrun_str::publish_module(lib);
}
