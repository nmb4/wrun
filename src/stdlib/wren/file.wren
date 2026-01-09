foreign class File {
    construct new() {}
    foreign static read(path)
    foreign static readBytes(path)
    foreign static write(path, content)
    foreign static writeBytes(path, bytes)
    foreign static append(path, content)
    foreign static exists(path)
    foreign static isFile(path)
    foreign static isDirectory(path)
    foreign static delete(path)
    foreign static copy(from, to)
    foreign static rename(from, to)
    foreign static mkdir(path)
    foreign static size(path)
}

foreign class Dir {
    construct new() {}
    foreign static list(path)
    foreign static create(path)
    foreign static remove(path)
    foreign static exists(path)
}

foreign class PathUtil {
    construct new() {}
    foreign static join(a, b)
    foreign static dirname(path)
    foreign static basename(path)
    foreign static extension(path)
    foreign static absolute(path)
    foreign static isAbsolute(path)
}

class Path {
    static join(a, b) { PathUtil.join(a, b) }
    static dirname(path) { PathUtil.dirname(path) }
    static basename(path) { PathUtil.basename(path) }
    static extension(path) { PathUtil.extension(path) }
    static absolute(path) { PathUtil.absolute(path) }
    static isAbsolute(path) { PathUtil.isAbsolute(path) }
}
