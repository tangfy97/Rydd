import Foundation
import FoundationModels

/// Layer ③ and the QA pass, using Apple's on-device model (SystemLanguageModel).
/// The model only ever sees folder paths, filenames and basic metadata — never file contents.
/// PrivateCloudComputeLanguageModel (Apple's server model) is deliberately not used.
final class LocalLLM {
    struct Profile: Codable {
        let purpose: String
        let keywords: [String]
    }

    /// What the model said about one file: `target` is nil when it answered NONE.
    struct Placement {
        let target: Int?
        let confidence: String
        let what: String
    }

    enum Verdict {
        case approve(String)
        case reject(String)
        case failed
    }

    private let model = SystemLanguageModel.default
    private let options = GenerationOptions(samplingMode: .greedy)
    private let verbose: Bool
    private(set) var calls = 0
    private(set) var failures = 0
    private(set) var seconds = 0.0

    init(verbose: Bool) { self.verbose = verbose }

    static var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available: return nil
        case .unavailable(.deviceNotEligible): return "This Mac doesn't support Apple Intelligence"
        case .unavailable(.appleIntelligenceNotEnabled): return "Apple Intelligence is turned off"
        case .unavailable(.modelNotReady): return "The on-device model isn't ready yet"
        case .unavailable: return "The on-device model isn't available"
        }
    }

    // MARK: Step 1 — understand the folder structure

    private struct CachedProfile: Codable {
        let signature: String
        let profile: Profile
    }

    /// One short purpose + keywords per folder, inferred from its path and the names inside it.
    /// With a cache file, only folders whose contents changed since last time are sent to the model.
    func profile(_ targets: [Target], cache: URL? = nil, batch: Int = 8) async -> [Int: Profile] {
        let signature = { (t: Target) in t.siblingNames.sorted().joined(separator: "\u{1F}") }
        var cached: [String: CachedProfile] = [:]
        if let cache, let data = try? Data(contentsOf: cache) {
            cached = (try? JSONDecoder().decode([String: CachedProfile].self, from: data)) ?? [:]
        }
        var out: [Int: Profile] = [:]
        for i in targets.indices where !targets[i].isProject {
            if let c = cached[targets[i].label], c.signature == signature(targets[i]) { out[i] = c.profile }
        }
        defer {
            if let cache {
                let fresh = Dictionary(uniqueKeysWithValues: out.map {
                    (targets[$0.key].label, CachedProfile(signature: signature(targets[$0.key]), profile: $0.value))
                })
                try? JSONEncoder().encode(fresh).write(to: cache)
            }
        }
        let ids = targets.indices.filter { !targets[$0].isProject && out[$0] == nil }
        for start in stride(from: 0, to: ids.count, by: batch) {
            let chunk = Array(ids[start..<min(start + batch, ids.count)])
            out.merge(await profileBatch(chunk, targets)) { a, _ in a }
            // One sensitive-looking folder name can make the whole batch refuse; retry the rest one by one.
            for i in chunk where out[i] == nil {
                out.merge(await profileBatch([i], targets)) { a, _ in a }
            }
        }
        return out
    }

    private func profileBatch(_ chunk: [Int], _ targets: [Target]) async -> [Int: Profile] {
        let labels = chunk.map { targets[$0].label }
        let folder = DynamicGenerationSchema(name: "Folder", properties: [
            .init(name: "path", schema: DynamicGenerationSchema(name: "Path", anyOf: labels)),
            .init(name: "purpose",
                  description: "What this folder is for, at most 10 words, specific enough to tell it apart from the other folders listed (e.g. \"Kitchen renovation quotes and drawings\" rather than \"Home documents\")",
                  schema: DynamicGenerationSchema(type: String.self)),
            .init(name: "keywords",
                  description: "6-10 words a file belonging here might have in its name, in English and in the folder's own language",
                  schema: DynamicGenerationSchema(arrayOf: DynamicGenerationSchema(type: String.self), maximumElements: 10)),
        ])
        let root = DynamicGenerationSchema(name: "Profiles", properties: [
            .init(name: "folders", schema: DynamicGenerationSchema(arrayOf: folder,
                                                                   minimumElements: chunk.count,
                                                                   maximumElements: chunk.count)),
        ])
        let prompt = chunk.map { describe(targets[$0], samples: 8) }.joined(separator: "\n")
        guard let content = await respond(
            instructions: "You look at the folders on a person's Mac and describe what each one is for, judging only from the folder path and the names of files inside it.",
            prompt: "Describe each of these folders:\n\(prompt)", root: root),
            let folders = try? content.value([GeneratedContent].self, forProperty: "folders")
        else { return [:] }
        var out: [Int: Profile] = [:]
        for f in folders {
            guard let path = try? f.value(String.self, forProperty: "path"),
                  let i = chunk.first(where: { targets[$0].label == path }) else { continue }
            out[i] = Profile(purpose: (try? f.value(String.self, forProperty: "purpose")) ?? "",
                             keywords: (try? f.value([String].self, forProperty: "keywords")) ?? [])
        }
        return out
    }

    // MARK: Step 2 — place a file the rules and similarity could not

    func place(_ f: FileItem, candidates: [Int], targets: [Target], profiles: [Int: Profile]) async -> Placement? {
        guard !candidates.isEmpty else { return nil }
        let labels = candidates.map { targets[$0].label }
        // Small models answer better when they first say what the file is, then pick.
        let root = DynamicGenerationSchema(name: "Placement", properties: [
            whatField,
            .init(name: "folder", schema: DynamicGenerationSchema(name: "FolderChoice", anyOf: ["NONE"] + labels)),
            .init(name: "confidence", schema: DynamicGenerationSchema(name: "Confidence", anyOf: ["high", "medium", "low"])),
        ])
        let folders = (["- NONE — none of the folders below is about this"] + candidates.map { i in
            "- \(targets[i].label)" + (profiles[i].map { " — \($0.purpose)" } ?? "")
        }).joined(separator: "\n")
        let instructions = """
            You help file downloaded files into a person's existing folders on their Mac. \
            You only see the file NAME, never its contents. First say what the file is. \
            Then pick the folder whose purpose matches it, or NONE if no folder is about it. \
            NONE is a good answer: a wrong move is worse than leaving the file alone.
            """
        guard let content = await respond(instructions: instructions,
                                          prompt: "\(describe(f))\n\nFolders:\n\(folders)", root: root),
              let folder = try? content.value(String.self, forProperty: "folder") else { return nil }
        return Placement(target: candidates.first { targets[$0].label == folder },
                         confidence: (try? content.value(String.self, forProperty: "confidence")) ?? "low",
                         what: (try? content.value(String.self, forProperty: "what")) ?? "")
    }

    // MARK: Step 3 — QA a proposed move

    /// Asking a small model "is this suggestion right?" gets nitpicks or rubber stamps. Instead it
    /// classifies the file again from scratch, among the proposed folder, a few look-alike folders
    /// (`alternatives`) and "something else" — and the move is approved only if it lands on the same folder.
    func review(_ f: FileItem, target t: Int, targets: [Target], profiles: [Int: Profile], alternatives: [Int]) async -> Verdict {
        var options: [String] = []
        for i in [t] + alternatives.filter({ $0 != t }) where options.count < 4 {
            let p = profiles[i]?.purpose ?? ""
            let o = "\(p.isEmpty ? targets[i].url.lastPathComponent : p) (\(targets[i].url.lastPathComponent))"
            if !options.contains(o) { options.append(o) }
        }
        let other = "something else"
        let root = DynamicGenerationSchema(name: "Review", properties: [
            .init(name: "english", description: "The file name translated to plain English words",
                  schema: DynamicGenerationSchema(type: String.self)),
            whatField,
            .init(name: "category", schema: DynamicGenerationSchema(name: "Category", anyOf: options.sorted() + [other])),
        ])
        let instructions = """
            You classify files on a person's Mac by their name. \
            File names may be in English, Norwegian, Chinese or other languages. \
            First say what the file is. Then pick the category it belongs to, or "\(other)" if none fits well.
            """
        guard let content = await respond(instructions: instructions, prompt: describe(f), root: root),
              let picked = try? content.value(String.self, forProperty: "category") else { return .failed }
        let what = (try? content.value(String.self, forProperty: "what")) ?? ""
        return picked == options[0] ? .approve(what) : .reject("\(picked)：\(what)")
    }

    // MARK: Helpers

    private var whatField: DynamicGenerationSchema.Property {
        .init(name: "what", description: "What this file most likely is, in at most 8 English words",
              schema: DynamicGenerationSchema(type: String.self))
    }

    private func describe(_ f: FileItem) -> String {
        var lines = ["File name: \"\(f.name)\"", "Type: \(f.kind.rawValue)"]
        if let d = f.sourceDomain { lines.append("Downloaded from: \(d)") }
        return lines.joined(separator: "\n")
    }

    private func describe(_ t: Target, samples: Int) -> String {
        let names = t.siblingNames.prefix(samples).map { String($0.prefix(40)) }
        return "- \(t.label)" + (names.isEmpty ? "" : "\n  files: " + names.joined(separator: ", "))
    }

    private func respond(instructions: String, prompt: String, root: DynamicGenerationSchema) async -> GeneratedContent? {
        calls += 1
        let t0 = Date()
        defer { seconds += Date().timeIntervalSince(t0) }
        do {
            let schema = try GenerationSchema(root: root, dependencies: [])
            let session = LanguageModelSession(model: model, instructions: instructions)
            return try await session.respond(to: prompt, schema: schema, includeSchemaInPrompt: true, options: options).content
        } catch {
            failures += 1
            if verbose { FileHandle.standardError.write("  [LLM] \(error)\n".data(using: .utf8)!) }
            return nil
        }
    }
}
