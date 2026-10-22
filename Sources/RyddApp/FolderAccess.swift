import AppKit
import Foundation

/// Folder access in the App Sandbox. Downloads comes with an entitlement; every other folder has to
/// be chosen once by the user in an open panel. Those choices are kept as app-scoped security-scoped
/// bookmarks, so Rydd can use the same folders again after a restart. Outside the sandbox (the
/// development build) everything is accessible and this keeps nothing.
@MainActor
final class FolderAccess {
    static let isSandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil

    /// The user's real home folder. Inside the sandbox, NSHomeDirectory() is the app's container.
    static var realHome: URL {
        guard let pw = getpwuid(getuid()) else { return URL(fileURLWithPath: NSHomeDirectory()) }
        return URL(fileURLWithPath: String(cString: pw.pointee.pw_dir), isDirectory: true)
    }

    private let defaults: UserDefaults
    private let key = "folderBookmarks"
    private(set) var granted: [URL] = []

    init(defaults: UserDefaults) {
        self.defaults = defaults
        guard Self.isSandboxed else { return }
        var fresh: [Data] = []
        for data in defaults.array(forKey: key) as? [Data] ?? [] {
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope,
                                     relativeTo: nil, bookmarkDataIsStale: &stale),
                  url.startAccessingSecurityScopedResource() else { continue }
            granted.append(url)
            fresh.append(stale ? (try? bookmark(url)) ?? data : data)
        }
        defaults.set(fresh, forKey: key)
    }

    /// Remembers folders the user just chose in an open panel.
    func remember(_ urls: [URL]) {
        guard Self.isSandboxed else { return }
        var saved = defaults.array(forKey: key) as? [Data] ?? []
        for url in urls where !granted.contains(url) {
            guard let data = try? bookmark(url), url.startAccessingSecurityScopedResource() else { continue }
            granted.append(url)
            saved.append(data)
        }
        defaults.set(saved, forKey: key)
    }

    /// Whether Rydd may read and write inside `url` without asking again.
    func allows(_ url: URL) -> Bool {
        guard Self.isSandboxed else { return true }
        let path = url.standardizedFileURL.path
        let downloads = Self.realHome.appendingPathComponent("Downloads").path
        return ([downloads] + granted.map(\.standardizedFileURL.path)).contains {
            path == $0 || path.hasPrefix($0 + "/")
        }
    }

    /// Asks the user to confirm access to their home folder: the open panel starts there, so one
    /// click on "Allow" grants it. Choosing narrower folders instead also works.
    func requestHome() -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.directoryURL = Self.realHome
        panel.prompt = String(localized: "Allow")
        panel.message = String(localized: "Click Allow to let Rydd tidy and file things in your home folder.")
        NSApp.activate()
        guard panel.runModal() == .OK else { return false }
        remember(panel.urls)
        return true
    }

    var hasHome: Bool { !Self.isSandboxed || granted.contains { $0.standardizedFileURL.path == Self.realHome.standardizedFileURL.path } }

    private func bookmark(_ url: URL) throws -> Data {
        try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    }
}
