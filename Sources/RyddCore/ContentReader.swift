import Foundation
import PDFKit

/// Opt-in only (--allow-content). Reads a small local excerpt of files that layers ①②
/// could not place. Nothing is stored, printed or sent anywhere — only keywords are kept
/// in memory for matching.
enum ContentReader {
    static let maxChars = 3000

    static func keywords(_ f: FileItem) -> [String]? {
        guard let text = excerpt(f) else { return nil }
        var freq: [String: Int] = [:]
        for t in Tokens.of(text) { freq[t, default: 0] += 1 }
        return freq.sorted { $0.value > $1.value }.prefix(30).map(\.key)
    }

    private static func excerpt(_ f: FileItem) -> String? {
        switch f.kind {
        case .pdf:
            guard let doc = PDFDocument(url: f.url) else { return nil }
            let pages = (0..<min(2, doc.pageCount)).compactMap { doc.page(at: $0)?.string }
            return String(pages.joined(separator: " ").prefix(maxChars))
        case .text, .spreadsheet:
            guard f.kind == .text || f.ext == "csv" else { return nil }
            guard let h = try? FileHandle(forReadingFrom: f.url) else { return nil }
            defer { try? h.close() }
            return (try? h.read(upToCount: 4096)).flatMap { String(data: $0, encoding: .utf8) }
        default:
            return nil
        }
    }
}
