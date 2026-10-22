import AppKit
import Foundation
import RyddCore

/// One file in the review window. `destination` starts as the engine's suggestion; the user can change it.
struct Row: Identifiable {
    var id: URL { suggestion.item.url }
    var suggestion: Suggestion
    var destination: Destination?
    var included: Bool
    var edited = false

    var item: FileItem { suggestion.item }
}

/// Rows that share a destination — the review window shows the plan folder by folder.
struct RowGroup: Identifiable {
    enum Kind: Hashable { case folder(URL), trash, unsorted }
    let kind: Kind
    var rows: [Row]
    var id: Kind { kind }
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var rows: [Row] = []
    @Published private(set) var targets: [Target] = []
    @Published private(set) var isBusy = false
    @Published private(set) var waiting = 0          // too new or still downloading
    @Published private(set) var lastBatch: Batch?
    @Published var showFailure = false

    @Published private(set) var sources: [URL]
    @Published private(set) var onboarded: Bool
    @Published var useLLM: Bool { didSet { settingsChanged() } }
    @Published var allowContent: Bool { didSet { settingsChanged() } }
    @Published var minAgeDays: Double { didSet { settingsChanged() } }

    let home: URL
    let llmUnavailable = Organizer.llmUnavailableReason.map { String(localized: String.LocalizationValue($0)) }
    private let supportDir: URL
    private let mover: FileMover
    private var organizer: Organizer!
    private var scanTask: Task<Void, Never>?
    private var rescanPending = false
    private var watchers: [String: DispatchSourceFileSystemObject] = [:]
    private var debounce: Task<Void, Never>?
    private let defaults: UserDefaults

    init() {
        // `--home <dir>` points the app at a test fixture instead of the real home folder.
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--home"), i + 1 < args.count {
            home = URL(fileURLWithPath: (args[i + 1] as NSString).expandingTildeInPath)
            supportDir = home.appendingPathComponent(".rydd-app")
            defaults = UserDefaults(suiteName: "app.rydd.Rydd.dev")!   // never touch the real settings
        } else {
            defaults = .standard
            home = URL(fileURLWithPath: NSHomeDirectory())
            supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Rydd")
        }
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        mover = FileMover(historyURL: supportDir.appendingPathComponent("history.json"))
        lastBatch = mover.history.last

        sources = (defaults.stringArray(forKey: "sources") ?? []).map { URL(fileURLWithPath: $0) }
        onboarded = defaults.bool(forKey: "onboarded") && !(defaults.stringArray(forKey: "sources") ?? []).isEmpty
        useLLM = defaults.object(forKey: "useLLM") as? Bool ?? (Organizer.llmUnavailableReason == nil)
        allowContent = defaults.bool(forKey: "allowContent")
        minAgeDays = defaults.object(forKey: "minAgeDays") as? Double ?? 3
        organizer = makeOrganizer()

        // Nothing is read until the user has picked folders in the welcome window.
        if onboarded {
            watchSources()
            rescan()
        }
    }

    /// Whether the welcome window should open at launch (read before the model exists).
    static var needsOnboarding: Bool {
        let devHome = CommandLine.arguments.contains("--home")
        let d = devHome ? UserDefaults(suiteName: "app.rydd.Rydd.dev")! : .standard
        return !d.bool(forKey: "onboarded") || (d.stringArray(forKey: "sources") ?? []).isEmpty
    }

    /// Folders worth offering in the welcome window.
    var suggestedSources: [URL] {
        ["Downloads", "Desktop"].map { home.appendingPathComponent($0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    func finishOnboarding(sources chosen: [URL], useLLM ai: Bool) {
        sources = chosen
        defaults.set(chosen.map(\.path), forKey: "sources")
        defaults.set(true, forKey: "onboarded")
        onboarded = true
        useLLM = ai          // saves settings, rebuilds the organizer and starts the first scan
        watchSources()
    }

    func pickFolders() -> [URL] {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.directoryURL = home
        panel.prompt = String(localized: "Add")
        NSApp.activate()
        return panel.runModal() == .OK ? panel.urls : []
    }

    // MARK: Derived

    var pending: [Row] { rows.filter { $0.destination != nil && $0.included } }
    var pendingCount: Int { pending.count }

    /// Folders first (largest group first), then Trash, then files without a place.
    var groups: [RowGroup] {
        var byKind: [RowGroup.Kind: [Row]] = [:]
        for r in rows {
            let k: RowGroup.Kind = switch r.destination {
            case .folder(let url): .folder(url)
            case .trash: .trash
            case nil: .unsorted
            }
            byKind[k, default: []].append(r)
        }
        let folders = byKind.compactMap { k, rows -> RowGroup? in
            if case .folder = k { return RowGroup(kind: k, rows: rows) } else { return nil }
        }
        .sorted { $0.rows.count != $1.rows.count ? $0.rows.count > $1.rows.count : title(of: $0.kind) < title(of: $1.kind) }
        return folders
            + (byKind[.trash].map { [RowGroup(kind: .trash, rows: $0)] } ?? [])
            + (byKind[.unsorted].map { [RowGroup(kind: .unsorted, rows: $0)] } ?? [])
    }

    var orderedRows: [Row] { groups.flatMap(\.rows) }

    func name(of destination: Destination) -> String {
        switch destination {
        case .trash: return title(of: .trash)
        case .folder(let url): return title(of: .folder(url))
        }
    }

    var folderChoices: [Target] {
        targets.filter { !$0.isProject }.sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
    }

    func title(of kind: RowGroup.Kind) -> String {
        switch kind {
        case .folder(let url):
            return url.path == "/Applications" ? String(localized: "Applications") : FileManager.default.displayName(atPath: url.path)
        case .trash: return String(localized: "Trash")
        case .unsorted: return String(localized: "Unsorted")
        }
    }

    /// "Documents/Finance" for a folder at ~/Documents/Finance/Invoices.
    func parentPath(of kind: RowGroup.Kind) -> String? {
        guard case .folder(let url) = kind else { return nil }
        let parent = url.deletingLastPathComponent().path
        if parent == home.path || url.path == "/Applications" { return nil }
        return parent.hasPrefix(home.path + "/") ? String(parent.dropFirst(home.path.count + 1)) : parent
    }

    func sourceName(_ url: URL) -> String { FileManager.default.displayName(atPath: url.path) }

    // MARK: Sources

    func addSource() {
        let picked = pickFolders()
        guard !picked.isEmpty else { return }
        for url in picked where !sources.contains(url) { sources.append(url) }
        sourcesChanged()
    }

    func removeSource(_ url: URL) {
        sources.removeAll { $0 == url }
        sourcesChanged()
    }

    private func sourcesChanged() {
        defaults.set(sources.map(\.path), forKey: "sources")
        watchSources()
        organizer = makeOrganizer()
        rescan()
    }

    // MARK: Scanning

    func rescan() {
        guard onboarded else { return }
        guard scanTask == nil else { rescanPending = true; return }
        let organizer = self.organizer!
        isBusy = true
        scanTask = Task {
            let plan = await organizer.run(partial: { plan in Task { @MainActor in self.merge(plan) } })
            merge(plan)
            isBusy = false
            scanTask = nil
            if rescanPending { rescanPending = false; rescan() }
        }
    }

    /// Takes a new plan but keeps whatever the user already changed by hand.
    private func merge(_ plan: Plan) {
        targets = plan.targets
        waiting = plan.suggestions.filter { $0.layer == .skip }.count
        let old = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        rows = plan.suggestions
            .filter { $0.layer != .skip && $0.layer != .userFolder }
            .map { s in
                if var o = old[s.id], o.edited { o.suggestion = s; return o }
                let d = s.destination(home: home)
                return Row(suggestion: s, destination: d, included: d != nil)
            }
    }

    private func makeOrganizer() -> Organizer {
        var s = OrganizerSettings(home: home)
        s.sources = sources
        s.useLLM = useLLM
        s.allowContent = allowContent
        s.minAgeDays = minAgeDays
        s.profileCache = supportDir.appendingPathComponent("folder-profiles.json")
        return Organizer(settings: s)
    }

    private func settingsChanged() {
        defaults.set(useLLM, forKey: "useLLM")
        defaults.set(allowContent, forKey: "allowContent")
        defaults.set(minAgeDays, forKey: "minAgeDays")
        organizer = makeOrganizer()
        rescan()
    }

    /// Rescan a few seconds after a watched folder changes (a download touches it several times).
    private func watchSources() {
        watchers.values.forEach { $0.cancel() }
        watchers = [:]
        for dir in sources {
            let fd = open(dir.path, O_EVTONLY)
            guard fd >= 0 else { continue }
            let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: .main)
            src.setEventHandler { [weak self] in
                Task { @MainActor in
                    self?.debounce?.cancel()
                    self?.debounce = Task { @MainActor in
                        try? await Task.sleep(for: .seconds(5))
                        if !Task.isCancelled { self?.rescan() }
                    }
                }
            }
            src.setCancelHandler { close(fd) }
            src.resume()
            watchers[dir.path] = src
        }
    }

    // MARK: Editing

    func setDestination(_ d: Destination?, for id: URL) {
        guard let i = rows.firstIndex(where: { $0.id == id }) else { return }
        rows[i].destination = d
        rows[i].included = d != nil
        rows[i].edited = true
    }

    func toggle(_ id: URL) {
        guard let i = rows.firstIndex(where: { $0.id == id }), rows[i].destination != nil else { return }
        rows[i].included.toggle()
        rows[i].edited = true
    }

    func chooseFolder(for id: URL) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = home.appendingPathComponent("Documents")
        panel.prompt = String(localized: "Move Here")
        if panel.runModal() == .OK, let url = panel.url { setDestination(.folder(url), for: id) }
    }

    // MARK: Apply and undo

    func applyAll() { apply(pending) }

    func applyOne(_ id: URL) {
        if let r = rows.first(where: { $0.id == id }), r.destination != nil { apply([r]) }
    }

    private func apply(_ selection: [Row]) {
        let moves = selection.compactMap { r in r.destination.map { (r.id, $0) } }
        guard !moves.isEmpty else { return }
        let (batch, failures) = mover.apply(moves)
        let done = Set(batch.records.map(\.original))
        rows.removeAll { done.contains($0.id) }
        lastBatch = mover.history.last
        showFailure = !failures.isEmpty
    }

    func undo() {
        let (_, failures) = mover.undoLast()
        lastBatch = mover.history.last
        showFailure = !failures.isEmpty
        rescan()
    }

    func reveal(_ id: URL) { NSWorkspace.shared.activateFileViewerSelecting([id]) }
}
