foreign class Str {
    construct new() {}

    // Validation
    foreign static isEmpty(s)
    foreign static isBlank(s)
    foreign static isNumeric(s)
    foreign static isAlpha(s)
    foreign static isAlphaNumeric(s)
    foreign static isUpper(s)
    foreign static isLower(s)

    // Transformation
    foreign static trim(s)
    foreign static trimStart(s)
    foreign static trimEnd(s)
    foreign static toUpper(s)
    foreign static toLower(s)
    foreign static capitalize(s)
    foreign static reverse(s)
    foreign static repeat(s, count)
    foreign static padStart(s, length, pad)
    foreign static padEnd(s, length, pad)
    foreign static camelCase(s)
    foreign static snakeCase(s)
    foreign static kebabCase(s)
    foreign static truncate(s, length)
    foreign static truncateWith(s, length, ellipsis)
    foreign static replace(s, old, new)
    foreign static replaceAll(s, old, new)

    // Search
    foreign static contains(s, sub)
    foreign static startsWith(s, prefix)
    foreign static endsWith(s, suffix)
    foreign static indexOf(s, sub)
    foreign static lastIndexOf(s, sub)
    foreign static count(s, sub)

    // Split/join
    foreign static split(s, sep)
    foreign static splitLimit(s, sep, limit)
    foreign static lines(s)
    foreign static chars(s)
    foreign static words(s)

    // Slice
    foreign static slice(s, start)
    foreign static sliceRange(s, start, end)
    foreign static at(s, index)

    // Length
    foreign static length(s)
    foreign static byteLength(s)
}
