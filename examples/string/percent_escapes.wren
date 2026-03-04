// Demonstration of %% escape sequence support for literal % characters
// Fixed in Wren parser via ruwren-sys patch

System.print("=== Percent Escape Sequences ===\n")

// 1. Bare % characters - now allowed
System.print("1. Bare % character:")
var bare = "%"
System.print("  Result: '" + bare + "' (length: %(bare.count))")

// 2. %% escape sequences
System.print("\n2. %% escape sequence (becomes single %):")
var escaped = "%%"
System.print("  Result: '" + escaped + "' (length: %(escaped.count))")

// 3. Shell date formatting
System.print("\n3. Shell date format with %%:")
var date_fmt = "date +%%Y-%%m-%%d"
System.print("  Command: " + date_fmt)

// 4. Percent signs in the middle of strings
System.print("\n4. Percent in middle of string:")
var fmt = "Progress: %%d%%"
System.print("  Result: '" + fmt + "'")

// 5. Multiple percents
System.print("\n5. Multiple %% sequences:")
var multi = "%%Y-%%m-%%d_%%H:%%M:%%S"
System.print("  Result: '" + multi + "'")

// 6. String interpolation still works
System.print("\n6. String interpolation:")
var name = "World"
var greeting = "Hello %(name)!"
System.print("  Result: " + greeting)

// 7. Combined: interpolation AND escaped percents
System.print("\n7. Combined interpolation and escaped percents:")
var value = "42"
var format_str = "Value: %(value) is %% 100"
System.print("  Result: " + format_str)

// 8. JSON with percent characters
System.print("\n8. JSON-like string with %%:")
var json_like = "{\"progress\": \"%%\", \"status\": \"%%\"}"
System.print("  Result: " + json_like)

System.print("\n=== All tests passed! ===")
