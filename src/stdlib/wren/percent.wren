// percent.wren - Utilities for working with literal % characters in strings
// Needed due to Wren string interpolation greedily consuming %
// Once Wren supports %% escape sequences, these utilities can be deprecated

class Percent {
  // Return a single literal % character
  static char {
    return Str.fromCharCode(37)
  }

  // Format a date pattern using % placeholders
  // Example: formatDate("Y-m-d") -> "%Y-%m-%d"
  static formatDate(pattern) {
    var pc = char
    var result = ""
    var i = 0
    while (i < pattern.count) {
      var ch = pattern[i]
      if (ch == "Y" || ch == "m" || ch == "d" || ch == "H" || ch == "M" || ch == "S") {
        result = result + pc + ch
      } else {
        result = result + ch
      }
      i = i + 1
    }
    return result
  }

  // Escape % for use in printf-style format strings
  // Example: escape("50% complete") -> "50%% complete"
  static escape(str) {
    return Str.replaceAll(str, "%", "%%" + "")
  }

  // Unescape %% back to %
  // Example: unescape("50%% complete") -> "50% complete"
  static unescape(str) {
    return Str.replaceAll(str, "%%" + "", "%")
  }
}
