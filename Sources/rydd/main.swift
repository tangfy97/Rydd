import Foundation
import RyddCore

// Rydd CLI — previews suggestions. Never moves anything, except --apply / --undo, which only work
// together with --home (a test fixture), so a typo can't reorganize your real Downloads.

struct Options {
    var settings = OrganizerSettings()
    var summaryOnly = false
    var verbose = false
    var expect: URL?
    var customHome = false
    var apply = false
    var undo = false

    init(_ args: [String]) {
        var it = args.dropFirst().makeIterator()
        var sources: [URL] = []
        let path = { (p: String) in URL(fileURLWithPath: (p as NSString).expandingTildeInPath) }
        while let a = it.next() {
            switch a {
            case "--source": if let p = it.next() { sources.append(path(p)) }
            case "--home": if let p = it.next() { settings.home = path(p); customHome = true }
            case "--summary": summaryOnly = true
            case "--expect": expect = it.next().map(path)
            case "--min-age": if let n = it.next(), let d = Double(n) { settings.minAgeDays = d }
            case "--threshold": if let n = it.next(), let d = Double(n) { settings.threshold = d }
            case "--allow-content": settings.allowContent = true
            case "--no-llm": settings.useLLM = false
            case "--no-qa": settings.useQA = false
            case "--profile-cache": settings.profileCache = it.next().map(path)
            case "--apply": apply = true
            case "--undo": undo = true
            case "-v", "--verbose": verbose = true; settings.verbose = true
            default: FileHandle.standardError.write("unknown option \(a)\n".data(using: .utf8)!); exit(2)
            }
        }
        settings.sources = sources.isEmpty ? [settings.home.appendingPathComponent("Downloads")] : sources
        if (apply || undo) && !customHome {
            FileHandle.standardError.write("--apply/--undo only work with --home (a test fixture)\n".data(using: .utf8)!)
            exit(2)
        }
    }
}

let opts = Options(CommandLine.arguments)
let s = opts.settings

if opts.undo {
    let mover = FileMover(historyURL: s.home.appendingPathComponent(".rydd-history.json"))
    let (restored, failures) = mover.undoLast()
    print("撤销：放回 \(restored) 个文件" + (failures.isEmpty ? "" : "，失败 \(failures.count) 个"))
    failures.forEach { print("  ✗ \($0.file.lastPathComponent)：\($0.message)") }
    exit(0)
}

print("Rydd 原型 · " + (opts.apply ? "会移动文件（测试目录）" : "只预览，不移动任何文件"))
print("读取范围：文件名、类型、大小、日期、下载来源域名" + (s.allowContent ? "；内容读取：已开启（仅本地，仅限无法归类的文件）" : "；内容读取：关闭"))
if s.useLLM, let why = Organizer.llmUnavailableReason { print("⚠︎ \(why)，跳过第③层和质检") }
print("来源：\(s.sources.map(\.path).joined(separator: "、"))\n")

let t0 = Date()
let plan = await Organizer(settings: s).run()
let final = plan.suggestions
let elapsed = Date().timeIntervalSince(t0)

// Report
let order: [Layer] = [.rule, .match, .llm, .content, .typeDefault, .none, .userFolder, .skip]
let titles: [Layer: String] = [
    .rule: "① 规则处理", .match: "② 归入你已有的文件夹", .llm: "③ 本地 LLM 按文件名归入",
    .content: "④ 读内容后归入（本地）", .typeDefault: "按类型放默认位置", .none: "需要你决定",
    .userFolder: "文件夹（默认不动）", .skip: "跳过",
]
for layer in order where !opts.summaryOnly {
    let group = final.filter { $0.layer == layer }
    guard !group.isEmpty else { continue }
    print("── \(titles[layer]!)（\(group.count)）")
    for x in group where opts.verbose || (layer != .skip && layer != .userFolder) {
        let domain = x.item.sourceDomain.map { "  ⟵ \($0)" } ?? ""
        print("  \(x.item.name)\(domain)\n      \(x.action.label)   \(x.reason)")
    }
    print("")
}

let eligible = final.filter { $0.layer != .skip && $0.layer != .userFolder }.count
let folders = final.filter { $0.layer == .userFolder }.count
let count = { (layers: [Layer]) in final.filter { layers.contains($0.layer) }.count }
let freed = final.filter { $0.action == .trash }.reduce(Int64(0)) { $0 + $1.item.size }
let pct = { (n: Int) in eligible > 0 ? String(format: "%.0f%%", Double(n) * 100 / Double(eligible)) : "-" }
let auto = count([.rule, .match, .llm, .content])

print("══ 汇总")
print("  条目总数 \(final.count)：可处理文件 \(eligible)，文件夹（不动）\(folders)，跳过 \(final.count - eligible - folders)")
print("  有明确建议：\(auto)（\(pct(auto))） = ①规则 \(count([.rule])) + ②相似度 \(count([.match])) + ③LLM \(count([.llm])) + ④内容 \(count([.content]))")
print("  按类型默认：\(count([.typeDefault]))（\(pct(count([.typeDefault]))))  需要你决定：\(count([.none]))（\(pct(count([.none]))))")
print("  可释放空间：\(ByteCountFormatter.string(fromByteCount: freed, countStyle: .file))")
print("  已知文件夹：\(plan.targets.count)（其中代码项目 \(plan.targets.filter(\.isProject).count) 个，只按名字匹配）")
if s.allowContent { print("  读取了 \(plan.contentReads) 个文件的内容（仅本地）") }
if s.useLLM && plan.llmUnavailable == nil {
    print("  LLM：理解了 \(plan.profiledFolders) 个文件夹，调用 \(plan.llmCalls) 次，失败/拒答 \(plan.llmFailures) 次，用时 \(String(format: "%.1f", plan.llmSeconds)) 秒")
    if s.useQA { print("  质检：通过 \(plan.qaApproved)，否决 \(plan.qaRejected)，未能判断 \(plan.qaFailed)") }
}
print("  总用时：\(String(format: "%.1f", elapsed)) 秒")

// Accuracy against a fixture's expected answers ("name<TAB>expected" per line, alternatives split by "|").
if let url = opts.expect, let text = try? String(contentsOf: url, encoding: .utf8) {
    var expected: [String: String] = [:]
    for line in text.split(separator: "\n") {
        let p = line.split(separator: "\t", maxSplits: 1).map(String.init)
        if p.count == 2 { expected[p[0]] = p[1] }
    }
    var right = 0, wrong = 0, asked = 0
    var misses: [String] = []
    for x in final {
        guard let want = expected[x.item.name] else { continue }
        let got = x.action.key
        if want.split(separator: "|").map(String.init).contains(got) { right += 1 }
        else if got == "ask" { asked += 1; misses.append("  ？ \(x.item.name)  期望 \(want)") }
        else { wrong += 1; misses.append("  ✗ \(x.item.name)  期望 \(want)，实际 \(got)（\(x.layer.rawValue)）") }
    }
    let decided = right + wrong
    print("\n══ 对照标准答案（\(expected.count) 项）")
    print("  正确 \(right)  错误 \(wrong)  交给用户 \(asked)")
    print("  给出建议时的准确率：\(decided > 0 ? String(format: "%.0f%%", Double(right) * 100 / Double(decided)) : "-")")
    misses.forEach { print($0) }
}

if opts.apply {
    let mover = FileMover(historyURL: s.home.appendingPathComponent(".rydd-history.json"))
    let moves = final.compactMap { x in x.destination(home: s.home).map { (x.item.url, $0) } }
    let (batch, failures) = mover.apply(moves)
    print("\n══ 已应用：移动 \(batch.records.count) 个文件" + (failures.isEmpty ? "" : "，失败 \(failures.count) 个"))
    failures.forEach { print("  ✗ \($0.file.lastPathComponent)：\($0.message)") }
}
