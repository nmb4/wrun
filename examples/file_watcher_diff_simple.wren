import "wrun/file" for Diff

var path = "examples/file_watcher_diff_simple.wren"
var before = "line 01: keep\nline 02: keep\nline 03: old alpha\nline 04: keep\nline 05: keep\nline 06: keep\nline 07: keep\nline 08: keep\nline 09: keep\nline 10: keep\nline 11: keep\nline 12: keep\nline 13: keep\nline 14: keep\nline 15: keep\nline 16: keep\nline 17: keep\nline 18: old omega\nline 19: keep\nline 20: keep\n"
var after = "line 01: keep\nline 02: keep\nline 03: new alpha\nline 04: keep\nline 05: keep\nline 06: keep\nline 07: keep\nline 08: keep\nline 09: keep\nline 10: keep\nline 11: keep\nline 12: keep\nline 13: keep\nline 14: keep\nline 15: keep\nline 16: keep\nline 17: keep\nline 18: new omega\nline 19: keep\nline 20: keep\n"

System.print("=== line granularity (myers) ===")
System.print(Diff.pretty(path, before, after, "line", "myers"))

System.print("=== line granularity (patience) ===")
System.print(Diff.pretty(path, before, after, "line", "patience"))
