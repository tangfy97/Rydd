import Foundation
import CoreServices
import UniformTypeIdentifiers

/// Everything Rydd knows about a file WITHOUT opening it:
/// name, type, size, dates, and where it was downloaded from (domain only).
public struct FileItem: Hashable {
    public let url: URL
    public let name: String
    public let ext: String
    public let isDirectory: Bool
    public let isPackage: Bool
    public let size: Int64
    public let added: Date?
    public let created: Date?
    public let lastUsed: Date?
    public let sourceDomain: String?
    public let quarantineAgent: String?
    public let kind: Kind

    public var stem: String { (name as NSString).deletingPathExtension }

    public var ageDays: Double {
        let ref = added ?? created ?? Date()
        return Date().timeIntervalSince(ref) / 86_400
    }

    static let keys: Set<URLResourceKey> = [
        .isDirectoryKey, .isPackageKey, .fileSizeKey, .totalFileAllocatedSizeKey,
        .addedToDirectoryDateKey, .creationDateKey, .isHiddenKey,
    ]

    static func load(_ url: URL) -> FileItem? {
        guard let v = try? url.resourceValues(forKeys: keys), v.isHidden != true else { return nil }
        let isDir = v.isDirectory ?? false
        let isPkg = v.isPackage ?? false
        let ext = url.pathExtension.lowercased()
        let md = MDItemCreateWithURL(kCFAllocatorDefault, url as CFURL)

        return FileItem(
            url: url,
            name: url.lastPathComponent,
            ext: ext,
            isDirectory: isDir && !isPkg,
            isPackage: isPkg,
            size: Int64(v.totalFileAllocatedSize ?? v.fileSize ?? 0),
            added: v.addedToDirectoryDate,
            created: v.creationDate,
            lastUsed: md.flatMap { MDItemCopyAttribute($0, kMDItemLastUsedDate) as? Date },
            sourceDomain: sourceDomain(url, md),
            quarantineAgent: quarantineAgent(url),
            kind: isDir && !isPkg ? .folder : Kind(ext: ext)
        )
    }

    /// Only the host of the download URL is kept; the full URL (which can carry tokens) is discarded.
    private static func sourceDomain(_ url: URL, _ md: MDItem?) -> String? {
        var froms = md.flatMap { MDItemCopyAttribute($0, kMDItemWhereFroms) as? [String] }
        if froms == nil, let data = xattr(url.path, "com.apple.metadata:kMDItemWhereFroms") {
            froms = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String]
        }
        for s in froms ?? [] {
            if let host = URL(string: s)?.host?.lowercased() {
                return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
            }
        }
        return nil
    }

    /// "0083;6538a1b2;Google Chrome;UUID" → "Google Chrome"
    private static func quarantineAgent(_ url: URL) -> String? {
        guard let data = xattr(url.path, "com.apple.quarantine"),
              let s = String(data: data, encoding: .utf8) else { return nil }
        let parts = s.split(separator: ";", omittingEmptySubsequences: false)
        guard parts.count > 2, !parts[2].isEmpty else { return nil }
        return String(parts[2])
    }

    private static func xattr(_ path: String, _ name: String) -> Data? {
        let len = getxattr(path, name, nil, 0, 0, 0)
        guard len > 0 else { return nil }
        var data = Data(count: len)
        let read = data.withUnsafeMutableBytes { getxattr(path, name, $0.baseAddress, len, 0, 0) }
        return read == len ? data : nil
    }
}

public enum Kind: String, Sendable {
    case image, video, audio, pdf, document, spreadsheet, presentation, text, code
    case archive, installer, app, font, folder, other

    /// A PDF next to .docx/.txt files is still "paperwork"; only cross-family moves are penalised.
    var family: String {
        switch self {
        case .pdf, .document, .spreadsheet, .presentation, .text: return "paper"
        default: return rawValue
        }
    }

    init(ext: String) {
        switch ext {
        case "dmg", "pkg", "mpkg", "exe", "msi", "apk", "iso": self = .installer
        case "zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz": self = .archive
        case "app": self = .app
        case "pdf": self = .pdf
        case "doc", "docx", "pages", "rtf", "odt": self = .document
        case "xls", "xlsx", "numbers", "csv", "ods": self = .spreadsheet
        case "ppt", "pptx", "key", "odp": self = .presentation
        case "txt", "md": self = .text
        case "ttf", "otf", "woff", "woff2": self = .font
        case "json", "swift", "py", "js", "ts", "html", "css", "sh", "yml", "yaml", "xml", "ipynb": self = .code
        default:
            guard let t = UTType(filenameExtension: ext) else { self = .other; return }
            if t.conforms(to: .image) { self = .image }
            else if t.conforms(to: .movie) || t.conforms(to: .video) { self = .video }
            else if t.conforms(to: .audio) { self = .audio }
            else if t.conforms(to: .sourceCode) { self = .code }
            else { self = .other }
        }
    }
}
