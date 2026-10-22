import Foundation

// The whole pipeline, shared by the CLI and the menu bar app. It only ever *suggests*;
// moving files is FileMover's job and always happens after the user confirms.

public enum Layer: String, Sendable {
    case skip = "跳过"
    case userFolder = "文件夹"
    case rule = "① 规则"
    case match = "② 相似度"
    case typeDefault = "② 类型默认"
    case llm = "③ 本地 LLM"
    case content = "④ 内容(本地)"
    case none = "—"
}

public enum Action: Hashable, Sendable {
    case move(String)        // folder path relative to home, e.g. "Documents/Finance/Invoices"
    case trash
    case toApplications
    case keep
    case ask

    /// Short form used to compare against a fixture's expected answers.
    public var key: String {
        switch self {
        case .move(let to): return to
        case .trash: return "trash"
        case .toApplications: return "/Applications"
        case .keep: return "keep"
        case .ask: return "ask"
        }
    }

    public var label: String {
        switch self {
        case .move(let to): return "→ \(to)"
        case .trash: return "→ 废纸篓"
        case .toApplications: return "→ /Applications"
        case .keep: return "保留"
        case .ask: return "需要你决定"
        }
    }
}

public struct Suggestion: Identifiable {
    public var id: URL { item.url }
    public let item: FileItem
    public var action: Action
    public var layer: Layer
    public var target: Int? = nil   // index into Plan.targets, for moves into the user's own folders
    public var score: Double? = nil
    public var reason: String
}

public struct OrganizerSettings: Sendable {
    public var home: URL
    public var sources: [URL]          // folders to tidy, e.g. Downloads and Desktop
    public var minAgeDays = 3.0
    public var allowContent = false
    public var useLLM = true
    public var useQA = true
    public var threshold = 0.45
    public var profileCache: URL?
    public var verbose = false

    public init(home: URL = URL(fileURLWithPath: NSHomeDirectory()), source: URL? = nil) {
        self.home = home
        self.sources = [source ?? home.appendingPathComponent("Downloads")]
    }
}

public enum OrganizerProgress: Sendable {
    case scanning
    case understandingFolders
    case placing(done: Int, total: Int)
    case reviewing(done: Int, total: Int)
}

public struct Plan {
    public var suggestions: [Suggestion] = []
    public var targets: [Target] = []
    public var isFinal = false
    public var llmUnavailable: String?
    public var profiledFolders = 0
    public var llmCalls = 0
    public var llmFailures = 0
    public var llmSeconds = 0.0
    public var contentReads = 0
    public var qaApproved = 0
    public var qaRejected = 0
    public var qaFailed = 0
}

public final class Organizer {
    public let settings: OrganizerSettings
    static let typeDefaults: [Kind: String] = [.image: "Pictures", .video: "Movies", .audio: "Music"]

    public init(settings: OrganizerSettings) { self.settings = settings }

    // LLM verdicts from earlier runs of this Organizer, so a background rescan after every change in
    // Downloads doesn't ask the model about the same file again. Cleared when the folder list changes.
    private var memo: [String: Suggestion] = [:]
    private var memoFolders = ""

    private static func memoKey(_ f: FileItem) -> String {
        "\(f.url.path)|\(f.size)|\(f.added?.timeIntervalSince1970 ?? 0)"
    }

    public static var llmUnavailableReason: String? { LocalLLM.unavailableReason }

    /// Folders the user already has. Code projects are kept as name-only targets.
    public static func roots(home: URL) -> [(URL, Int)] {
        var roots: [(URL, Int)] = [
            (home.appendingPathComponent("Documents"), 3),
            (home.appendingPathComponent("Desktop"), 2),
            (home.appendingPathComponent("Pictures"), 2),
            (home.appendingPathComponent("Movies"), 2),
            (home.appendingPathComponent("Music"), 2),
        ]
        let iCloud = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        if FileManager.default.fileExists(atPath: iCloud.path) { roots.append((iCloud, 2)) }
        return roots
    }

    /// Runs the pipeline. `partial` receives a complete-but-preliminary plan as soon as rules and
    /// similarity are done (well under a second), so a UI can show it while the local LLM works.
    public func run(progress: @escaping (OrganizerProgress) -> Void = { _ in },
                    partial: @escaping (Plan) -> Void = { _ in }) async -> Plan {
        let s = settings
        progress(.scanning)
        let items = s.sources.flatMap { dir in
            ((try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: Array(FileItem.keys), options: [.skipsHiddenFiles])) ?? [])
                .compactMap(FileItem.load)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        var plan = Plan()
        // A folder being tidied is never itself a destination.
        let sourcePaths = Set(s.sources.map(\.standardizedFileURL.path))
        plan.targets = TargetFinder.find(roots: Self.roots(home: s.home), home: s.home)
            .filter { !sourcePaths.contains($0.url.standardizedFileURL.path) }
        let targets = plan.targets
        let fileTokens = items.map { f in
            Tokens.of(f.stem) + (f.sourceDomain.map { Tokens.of($0.components(separatedBy: ".").dropLast().joined(separator: " ")) } ?? [])
        }
        let matcher = Matcher(targets: targets, extraDocs: fileTokens)
        let rules = Rules(siblings: items, installedApps: Rules.installedApps(), minAgeDays: s.minAgeDays)
        let folderSignature = targets.map(\.label).joined(separator: "\n")
        if folderSignature != memoFolders { memo = [:]; memoFolders = folderSignature }

        func place(_ f: FileItem, tokens: [String], layer: Layer) -> Suggestion? {
            let ranked = matcher.rank(tokens, kind: f.kind)
            guard let best = ranked.first, best.score >= s.threshold else { return nil }
            let bestTarget = targets[best.target]
            // Ambiguous between two unrelated folders → let the user decide.
            if let second = ranked.dropFirst().first, best.score - second.score < 0.08,
               !targets[second.target].url.path.hasPrefix(bestTarget.url.path),
               !bestTarget.url.path.hasPrefix(targets[second.target].url.path) {
                return nil
            }
            // Never file things into a code repository on our own.
            if bestTarget.isProject {
                return Suggestion(item: f, action: .ask, layer: .none,
                                  reason: "可能属于代码项目「\(bestTarget.label)」，请你决定")
            }
            return Suggestion(item: f, action: .move(bestTarget.label), layer: layer, target: best.target,
                              score: best.score, reason: "\(best.why) · \(String(format: "%.2f", best.score))")
        }

        func fallback(_ i: Int) -> Suggestion {
            let f = items[i]
            if let dest = Self.typeDefaults[f.kind] {
                return Suggestion(item: f, action: .move(dest), layer: .typeDefault, reason: "按类型的默认位置")
            }
            var why = fileTokens[i].isEmpty ? "文件名没有可用信息" : "没有足够相似的文件夹"
            if let best = matcher.rank(fileTokens[i], kind: f.kind).first {
                why += "（最接近：\(targets[best.target].label)）"
            }
            return Suggestion(item: f, action: .ask, layer: .none, reason: why)
        }

        // ①② rules, then similarity to existing folders.
        var results: [Suggestion?] = items.indices.map { i in
            rules.apply(items[i]) ?? place(items[i], tokens: fileTokens[i], layer: .match)
        }
        let open = { results.indices.filter { results[$0] == nil } }
        plan.suggestions = results.indices.map { results[$0] ?? fallback($0) }
        partial(plan)

        // ③ the on-device LLM reads the folder structure (cached), then places what's left — by name only.
        let useLLM = s.useLLM && LocalLLM.unavailableReason == nil
        plan.llmUnavailable = s.useLLM ? LocalLLM.unavailableReason : nil
        let llm = LocalLLM(verbose: s.verbose)
        var profiles: [Int: LocalLLM.Profile] = [:]
        // Only wake the model when there's something for it: files left to place, or weak matches to check.
        let notForLLM: Set<Kind> = [.installer, .archive, .app, .font]
        let llmWork = open().contains { !fileTokens[$0].isEmpty && !notForLLM.contains(items[$0].kind) }
            || results.contains { $0?.layer == .match && ($0?.score ?? 1) < 0.65 }
        if useLLM && llmWork {
            progress(.understandingFolders)
            profiles = await llm.profile(targets, cache: s.profileCache)
            plan.profiledFolders = profiles.count
            // Names with no usable words (IMG_2034, scan0012, a8f3e2d1) are never sent: the model would only guess.
            var todo = open().filter { !fileTokens[$0].isEmpty && !notForLLM.contains(items[$0].kind) }
            for i in todo { if let m = memo[Self.memoKey(items[i])] { results[i] = m } }
            todo = todo.filter { memo[Self.memoKey(items[$0])] == nil }
            for (n, i) in todo.enumerated() {
                progress(.placing(done: n, total: todo.count))
                let f = items[i]
                let candidates = matcher.shortlist(fileTokens[i], kind: f.kind, profiles: profiles, k: 20)
                if let p = await llm.place(f, candidates: candidates, targets: targets, profiles: profiles),
                   let t = p.target, p.confidence != "low" {
                    results[i] = Suggestion(item: f, action: .move(targets[t].label), layer: .llm,
                                            target: t, reason: "\(p.what) · \(p.confidence)")
                }
                // Remember "no folder fits" too; placements are remembered after QA.
                if results[i] == nil || !s.useQA { memo[Self.memoKey(f)] = results[i] ?? fallback(i) }
            }
        }

        // ④ opt-in local content, only for what names could not place.
        if s.allowContent {
            for i in open() {
                guard let kw = ContentReader.keywords(items[i]) else { continue }
                plan.contentReads += 1
                results[i] = place(items[i], tokens: fileTokens[i] + kw, layer: .content)
            }
        }
        var final = results.indices.map { results[$0] ?? fallback($0) }

        // QA: every LLM placement and every weak similarity match is re-checked. Rejected → ask the user.
        if useLLM && llmWork && s.useQA {
            // Near-identical name matches (e.g. "体检报告2025" → "体检报告2026") don't need a second opinion.
            let needsQA = final.indices.filter { i in
                let x = final[i]
                return x.target != nil && (x.layer == .llm || ([.match, .content].contains(x.layer) && (x.score ?? 0) < 0.65))
            }
            for i in needsQA { if let m = memo[Self.memoKey(final[i].item)] { final[i] = m } }
            let todo = needsQA.filter { memo[Self.memoKey(final[$0].item)] == nil }
            for (n, i) in todo.enumerated() {
                progress(.reviewing(done: n, total: todo.count))
                let x = final[i]
                let alternatives = matcher.shortlist(fileTokens[i], kind: x.item.kind, profiles: profiles, k: 6)
                switch await llm.review(x.item, target: x.target!, targets: targets, profiles: profiles, alternatives: alternatives) {
                case .approve: plan.qaApproved += 1
                case .failed: plan.qaFailed += 1
                case .reject(let why):
                    plan.qaRejected += 1
                    final[i] = Suggestion(item: x.item, action: .ask, layer: .none,
                                          reason: "质检否决（原建议 \(x.action.key)，\(x.layer.rawValue)）：\(why)")
                }
                memo[Self.memoKey(x.item)] = final[i]
            }
        }

        plan.suggestions = final
        plan.isFinal = true
        plan.llmCalls = llm.calls
        plan.llmFailures = llm.failures
        plan.llmSeconds = llm.seconds
        return plan
    }
}
