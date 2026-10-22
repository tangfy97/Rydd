import Foundation

/// Layer ①: deterministic rules on name + metadata only.
struct Rules {
    let siblings: [FileItem]
    let installedApps: Set<String>
    let minAgeDays: Double

    static let screenshotPattern = "^(Screenshot|Screen Shot|Skjermbilde|Bildschirmfoto|Capture d’écran|截屏|屏幕快照|Screen Recording|Skjermopptak|录屏)"
    static let partialExts: Set<String> = ["crdownload", "download", "part", "partial"]

    static func installedApps() -> Set<String> {
        let dirs = ["/Applications", NSHomeDirectory() + "/Applications", "/System/Applications"]
        var out: Set<String> = []
        for d in dirs {
            for n in (try? FileManager.default.contentsOfDirectory(atPath: d)) ?? [] where n.hasSuffix(".app") {
                out.insert(normalize((n as NSString).deletingPathExtension))
            }
        }
        return out
    }

    static func normalize(_ s: String) -> String {
        s.lowercased().filter { $0.isLetter }
    }

    func apply(_ f: FileItem) -> Suggestion? {
        if Self.partialExts.contains(f.ext) {
            return Suggestion(item: f, action: .keep, layer: .skip, reason: "正在下载")
        }
        if f.kind == .folder {
            // A folder in Downloads is usually structure the user made on purpose — leave it.
            return Suggestion(item: f, action: .keep, layer: .userFolder, reason: "文件夹，默认保持原样")
        }
        if f.ageDays < minAgeDays {
            return Suggestion(item: f, action: .keep, layer: .skip,
                              reason: "太新（\(String(format: "%.1f", f.ageDays)) 天），暂不处理")
        }
        if f.name.range(of: Self.screenshotPattern, options: [.regularExpression, .caseInsensitive]) != nil {
            let isVideo = f.kind == .video
            return Suggestion(item: f, action: .move(isVideo ? "Movies/Screen Recordings" : "Pictures/Screenshots"),
                              layer: .rule, reason: isVideo ? "录屏" : "截图")
        }
        if f.kind == .app {
            return Suggestion(item: f, action: .toApplications, layer: .rule, reason: "应用程序放在下载文件夹")
        }
        if f.kind == .installer {
            let key = Self.normalize(f.stem.components(separatedBy: CharacterSet.decimalDigits).first ?? f.stem)
            if key.count >= 4, installedApps.contains(where: { $0.hasPrefix(key) || (key.hasPrefix($0) && $0.count >= 4) }) {
                return Suggestion(item: f, action: .trash, layer: .rule, reason: "安装包，应用已安装")
            }
            if f.ageDays > 30 {
                return Suggestion(item: f, action: .trash, layer: .rule,
                                  reason: "旧安装包（\(Int(f.ageDays)) 天）")
            }
        }
        if f.kind == .archive {
            let base = f.name.replacingOccurrences(of: "\\.(tar\\.gz|tar\\.xz|[a-z0-9]+)$", with: "",
                                                   options: [.regularExpression, .caseInsensitive])
            if siblings.contains(where: { $0.kind == .folder && $0.name == base && sameFolder($0, f) }) {
                return Suggestion(item: f, action: .trash, layer: .rule, reason: "已解压（旁边有同名文件夹）")
            }
        }
        if ["torrent", "ics"].contains(f.ext) {
            return Suggestion(item: f, action: .trash, layer: .rule, reason: "一次性文件（.\(f.ext)）")
        }
        if let original = duplicateOf(f) {
            return Suggestion(item: f, action: .trash, layer: .rule,
                              reason: "重复下载（同名同大小：\(original.name)）")
        }
        return nil
    }

    /// "report (1).pdf" next to "report.pdf" with identical size. Size+name is metadata;
    /// confirming byte-for-byte would need a hash, i.e. reading content — so we don't.
    private func duplicateOf(_ f: FileItem) -> FileItem? {
        guard !f.isDirectory,
              let r = f.stem.range(of: "( ?\\(\\d+\\)| copy| kopi| 副本| - Copy)$", options: .regularExpression)
        else { return nil }
        let base = String(f.stem[..<r.lowerBound])
        let originalName = f.ext.isEmpty ? base : "\(base).\(f.ext)"
        return siblings.first { $0.name == originalName && $0.size == f.size && sameFolder($0, f) }
    }

    private func sameFolder(_ a: FileItem, _ b: FileItem) -> Bool {
        a.url.deletingLastPathComponent() == b.url.deletingLastPathComponent()
    }
}
