import Foundation
import NaturalLanguage

/// Turns a filename into meaningful words. Handles CJK via NLTokenizer,
/// drops numbers, random IDs and filler words like "copy" / "final" / "副本".
enum Tokens {
    private static let tokenizer = NLTokenizer(unit: .word)

    static let stopwords: Set<String> = [
        "img", "image", "images", "file", "files", "copy", "final", "new", "untitled", "document",
        "documents", "doc", "scan", "download", "downloads", "screenshot", "screen", "shot",
        "the", "and", "of", "for", "to", "in", "on", "with", "at", "am", "pm", "by", "from",
        "kopi", "dokument", "fil", "og", "til", "av", "på", "med", "bilde", "skjermbilde",
        "pdf", "jpg", "jpeg", "png", "heic", "gif", "mp4", "mov", "zip", "dmg",
        "export", "exported", "edited", "version", "draft", "report", "note", "notes",
        "副本", "未命名", "的", "和", "文件", "图片", "截屏", "截图",
    ]

    static func of(_ text: String) -> [String] {
        var s = text.replacingOccurrences(of: "[_\\-\\.\\+\\(\\)\\[\\]{}@#,;]", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
        tokenizer.string = s
        var out: [String] = []
        tokenizer.enumerateTokens(in: s.startIndex..<s.endIndex) { range, _ in
            let raw = String(s[range])
            let t = stem(raw.lowercased())
            if keep(t, acronym: raw.count == 2 && raw.allSatisfy(\.isUppercase)) { out.append(t) }
            return true
        }
        return out
    }

    /// Crude plural folding so "Wallpapers" ≈ "wallpaper", "Invoices" ≈ "invoice".
    private static func stem(_ t: String) -> String {
        guard t.count > 4, t.hasSuffix("s"), !t.hasSuffix("ss"), t.allSatisfy(\.isASCII) else { return t }
        return String(t.dropLast())
    }

    private static func keep(_ t: String, acronym: Bool) -> Bool {
        // Latin words need 3+ letters ("da", "en" are locale codes, not topics) unless written
        // as an acronym like "CV"; CJK words 2+.
        let isCJK = t.unicodeScalars.contains { $0.value >= 0x2E80 }
        guard t.count >= (isCJK || acronym ? 2 : 3), !stopwords.contains(t) else { return false }
        // Any digit makes it a number, version or random id (2026, v2, 77b2, a8f3e2d1), not a topic.
        return !t.contains(where: \.isNumber)
    }
}
