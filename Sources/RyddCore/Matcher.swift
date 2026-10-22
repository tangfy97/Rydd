import Foundation
import NaturalLanguage

typealias Vec = [String: Double]

struct Match {
    let target: Int
    let score: Double
    let why: String
}

/// Layer ②: "which of your existing folders does this filename look like it belongs in?"
/// TF-IDF over filenames (kNN against files already in each folder + the folder's own name),
/// with the system's built-in sentence embedding as a weak semantic fallback. Fully offline.
final class Matcher {
    let targets: [Target]
    private var idf: [String: Double] = [:]
    private var siblingVecs: [[Vec]] = []
    private var nameVecs: [Vec] = []
    private var centroids: [Vec] = []
    private var index: [String: [(t: Int, s: Int)]] = [:]
    private let embedding = NLEmbedding.sentenceEmbedding(for: .english)
    private var nameEmbeddings: [[Double]?] = []

    init(targets: [Target], extraDocs: [[String]]) {
        self.targets = targets
        let siblingTokens = targets.map { $0.siblingNames.map { Tokens.of(($0 as NSString).deletingPathExtension) } }
        let nameTokens = targets.map { Tokens.of($0.url.lastPathComponent) }

        var df: [String: Int] = [:]
        var n = 0
        for doc in siblingTokens.flatMap({ $0 }) + nameTokens + extraDocs {
            n += 1
            for t in Set(doc) { df[t, default: 0] += 1 }
        }
        idf = df.mapValues { log(Double(n + 1) / Double($0 + 1)) + 1 }

        siblingVecs = siblingTokens.map { $0.map(vector) }
        nameVecs = nameTokens.map(vector)
        // The folder as a whole: all its filenames + its own name in one bag of words.
        centroids = targets.indices.map { vector(siblingTokens[$0].flatMap { $0 } + nameTokens[$0]) }
        for (ti, vecs) in siblingVecs.enumerated() {
            for (si, v) in vecs.enumerated() { for t in v.keys { index[t, default: []].append((ti, si)) } }
        }
        nameEmbeddings = nameTokens.map { $0.isEmpty ? nil : embedding?.vector(for: $0.joined(separator: " ")) }
    }

    func vector(_ tokens: [String]) -> Vec {
        var v: Vec = [:]
        for t in tokens { v[t, default: 0] += idf[t] ?? 1 }
        let norm = sqrt(v.values.reduce(0) { $0 + $1 * $1 })
        return norm > 0 ? v.mapValues { $0 / norm } : v
    }

    /// Ranked candidate folders for a set of tokens describing one file.
    func rank(_ tokens: [String], kind: Kind) -> [Match] {
        let fv = vector(tokens)
        guard !fv.isEmpty else { return [] }
        var knn: [Int: (Double, Int)] = [:]
        for t in fv.keys {
            for (ti, si) in index[t] ?? [] {
                let s = cosine(fv, siblingVecs[ti][si])
                if s > (knn[ti]?.0 ?? 0) { knn[ti] = (s, si) }
            }
        }

        let fe = embedding?.vector(for: tokens.joined(separator: " "))
        var out: [Match] = []
        for ti in targets.indices {
            let name = cosine(fv, nameVecs[ti])
            let near = knn[ti]?.0 ?? 0
            let whole = cosine(fv, centroids[ti])
            var score = max(name, near, whole)
            var why = score == near
                ? (knn[ti].map { "像 “\(targets[ti].siblingNames[$0.1])”" } ?? "")
                : score == name ? "文件夹名称相符" : "和整个文件夹的用词相近"
            if score < 0.2, let fe, let ne = nameEmbeddings[ti] {
                let sem = cosine(fe, ne)
                if sem > 0.75 { score = (sem - 0.75) * 2; why = "语义相近 \(String(format: "%.2f", sem))" }
            }
            let t = targets[ti]
            if !t.kinds.isEmpty && !t.kinds.contains(where: { $0.family == kind.family }) && kind != .folder { score *= 0.75 }
            if score > 0.05 { out.append(Match(target: ti, score: score, why: why)) }
        }
        return out.sorted { $0.score > $1.score }
    }

    private func cosine(_ a: Vec, _ b: Vec) -> Double {
        let (small, big) = a.count < b.count ? (a, b) : (b, a)
        return small.reduce(0) { $0 + $1.value * (big[$1.key] ?? 0) }
    }

    private func cosine(_ a: [Double], _ b: [Double]) -> Double {
        var dot = 0.0, na = 0.0, nb = 0.0
        for i in a.indices { dot += a[i] * b[i]; na += a[i] * a[i]; nb += b[i] * b[i] }
        return na > 0 && nb > 0 ? dot / (sqrt(na) * sqrt(nb)) : 0
    }
}

extension Matcher {
    /// Recall step before asking the LLM: the k folders whose name, purpose or keywords look most
    /// related to this file. Small setups skip it and show the model every folder.
    func shortlist(_ tokens: [String], kind: Kind, profiles: [Int: LocalLLM.Profile], k: Int) -> [Int] {
        // Hard filters the small model can't be trusted with: no code projects, only folders that
        // already hold this kind of file, and no empty "container" folders whose subfolders are listed.
        let candidates = targets.indices.filter { i in
            let t = targets[i]
            if t.isProject { return false }
            if t.siblingNames.isEmpty {
                return !targets.contains { $0.url.deletingLastPathComponent() == t.url }
            }
            return t.kinds.contains { $0.family == kind.family }
        }
        guard candidates.count > k else { return candidates }
        let fv = vector(tokens)
        let fe = embedding?.vector(for: tokens.joined(separator: " "))
        let scored = candidates.map { i -> (Int, Double) in
            let p = profiles[i]
            let words = [targets[i].url.lastPathComponent, p?.purpose ?? ""] + (p?.keywords ?? [])
            var s = cosine(fv, vector(words.flatMap(Tokens.of)))
            if let fe, let pe = embedding?.vector(for: words.joined(separator: " ")) { s = max(s, cosine(fe, pe)) }
            return (i, s)
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(k).map(\.0)
    }
}
