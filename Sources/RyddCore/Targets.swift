import Foundation

/// A folder the user already has, which a file could be filed into.
/// We only list names inside it — never open the files.
public struct Target {
    public let url: URL
    public let label: String
    public let isProject: Bool
    public let siblingNames: [String]
    public let kinds: Set<Kind>
}

enum TargetFinder {
    static let projectMarkers: Set<String> = [
        ".git", "Package.swift", "package.json", "Cargo.toml", "pyproject.toml", "go.mod",
        "Gemfile", "pom.xml", "build.gradle", "requirements.txt", "Podfile", "CMakeLists.txt",
        "manifest.json",
    ]
    static let skipNames: Set<String> = [
        "node_modules", ".build", "build", "dist", "venv", ".venv", "__pycache__", "DerivedData", "Pods",
        "_locales",
    ]
    static let maxSiblings = 200

    /// Walks roots to `depth`, stops at code projects (they're kept as name-only targets).
    static func find(roots: [(URL, Int)], home: URL) -> [Target] {
        var out: [Target] = []
        for (root, depth) in roots where FileManager.default.fileExists(atPath: root.path) {
            walk(root, depth: depth, home: home, isRoot: true, into: &out)
        }
        return out
    }

    private static func walk(_ dir: URL, depth: Int, home: URL, isRoot: Bool, into out: inout [Target]) {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey]
        guard let children = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: keys,
                                                         options: [.skipsHiddenFiles]) else { return }
        let names = Set((try? fm.contentsOfDirectory(atPath: dir.path)) ?? [])
        let isProject = !isRoot && (!names.isDisjoint(with: projectMarkers)
            || names.contains { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") })

        var files: [String] = []
        var subdirs: [URL] = []
        for c in children {
            let v = try? c.resourceValues(forKeys: Set(keys))
            if v?.isDirectory == true && v?.isPackage != true {
                if !skipNames.contains(c.lastPathComponent) { subdirs.append(c) }
            } else {
                files.append(c.lastPathComponent)
            }
        }

        if !isRoot {
            let label = dir.path.replacingOccurrences(of: home.path + "/", with: "")
            out.append(Target(
                url: dir, label: label, isProject: isProject,
                siblingNames: isProject ? [] : Array(files.prefix(maxSiblings)),
                kinds: Set(files.map { Kind(ext: ($0 as NSString).pathExtension.lowercased()) })
            ))
        }
        guard depth > 0, !isProject else { return }
        for s in subdirs { walk(s, depth: depth - 1, home: home, isRoot: false, into: &out) }
    }
}
