import Foundation

public enum Destination: Hashable, Sendable {
    case folder(URL)
    case trash
}

public struct MoveRecord: Codable, Sendable {
    public let original: URL
    public let moved: URL
}

/// One "apply" from the user — the unit of undo.
public struct Batch: Codable, Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public var records: [MoveRecord]
    public var createdFolders: [URL] = []   // removed again on undo if still empty
}

public struct MoveFailure: Sendable {
    public let file: URL
    public let message: String
}

/// Moves files after the user confirms, and can put them back. Never deletes and never overwrites:
/// "trash" means the macOS Trash, and name clashes get " 2", " 3"… The history survives restarts.
public final class FileMover {
    public let historyURL: URL?
    public private(set) var history: [Batch] = []
    private let fm = FileManager.default
    static let keepBatches = 20

    public init(historyURL: URL?) {
        self.historyURL = historyURL
        if let historyURL, let data = try? Data(contentsOf: historyURL) {
            history = (try? JSONDecoder().decode([Batch].self, from: data)) ?? []
        }
    }

    public func apply(_ moves: [(URL, Destination)]) -> (batch: Batch, failures: [MoveFailure]) {
        var batch = Batch(id: UUID(), date: Date(), records: [], createdFolders: [])
        var failures: [MoveFailure] = []
        for (source, destination) in moves {
            guard fm.fileExists(atPath: source.path) else {
                failures.append(MoveFailure(file: source, message: "文件已不在原处"))
                continue
            }
            do {
                switch destination {
                case .trash:
                    var resulting: NSURL?
                    try fm.trashItem(at: source, resultingItemURL: &resulting)
                    if let r = resulting as URL? { batch.records.append(MoveRecord(original: source, moved: r)) }
                case .folder(let dir):
                    batch.createdFolders += try createFolder(dir)
                    let target = uniqueURL(dir.appendingPathComponent(source.lastPathComponent))
                    try move(source, to: target)
                    batch.records.append(MoveRecord(original: source, moved: target))
                }
            } catch {
                failures.append(MoveFailure(file: source, message: error.localizedDescription))
            }
        }
        if !batch.records.isEmpty {
            history.append(batch)
            history = Array(history.suffix(Self.keepBatches))
            save()
        }
        return (batch, failures)
    }

    /// Puts the files of the most recent batch back where they came from.
    @discardableResult
    public func undoLast() -> (restored: Int, failures: [MoveFailure]) {
        guard let batch = history.popLast() else { return (0, []) }
        var restored = 0
        var failures: [MoveFailure] = []
        for r in batch.records.reversed() {
            guard fm.fileExists(atPath: r.moved.path) else {
                failures.append(MoveFailure(file: r.moved, message: "找不到已移动的文件"))
                continue
            }
            do {
                try fm.createDirectory(at: r.original.deletingLastPathComponent(), withIntermediateDirectories: true)
                try move(r.moved, to: uniqueURL(r.original))
                restored += 1
            } catch {
                failures.append(MoveFailure(file: r.moved, message: error.localizedDescription))
            }
        }
        for dir in batch.createdFolders.reversed()
        where (try? fm.contentsOfDirectory(atPath: dir.path).filter { $0 != ".DS_Store" }.isEmpty) == true {
            try? fm.removeItem(at: dir)
        }
        save()
        return (restored, failures)
    }

    /// Creates `dir` and any missing parents; returns the ones it created, outermost first.
    private func createFolder(_ dir: URL) throws -> [URL] {
        var missing: [URL] = []
        var d = dir
        while !fm.fileExists(atPath: d.path) {
            missing.insert(d, at: 0)
            d = d.deletingLastPathComponent()
        }
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return missing
    }

    /// rename(2) keeps the file name byte-for-byte (FileManager.moveItem rewrites "å" to its
    /// decomposed form); fall back to FileManager across volumes.
    private func move(_ from: URL, to: URL) throws {
        if rename(from.path, to.path) == 0 { return }
        if errno == EXDEV { try fm.moveItem(at: from, to: to); return }
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }

    /// "report.pdf" → "report 2.pdf" → "report 3.pdf" … until the name is free.
    func uniqueURL(_ url: URL) -> URL {
        guard fm.fileExists(atPath: url.path) else { return url }
        let dir = url.deletingLastPathComponent()
        let ext = url.pathExtension
        let stem = url.deletingPathExtension().lastPathComponent
        for n in 2... {
            let candidate = dir.appendingPathComponent(ext.isEmpty ? "\(stem) \(n)" : "\(stem) \(n).\(ext)")
            if !fm.fileExists(atPath: candidate.path) { return candidate }
        }
        return url
    }

    private func save() {
        guard let historyURL else { return }
        try? fm.createDirectory(at: historyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(history).write(to: historyURL)
    }
}

extension Suggestion {
    /// Where this suggestion would move the file, or nil if it shouldn't move.
    public func destination(home: URL) -> Destination? {
        switch action {
        case .move(let rel): return .folder(home.appendingPathComponent(rel))
        case .trash: return .trash
        case .toApplications: return .folder(URL(fileURLWithPath: "/Applications"))
        case .keep, .ask: return nil
        }
    }
}
