// Data layer: talks to the local Anas HQ server (SQLite underneath), keeps a live copy in memory.
import Foundation
import SwiftUI
import AppKit

let serverBase = URL(string: "http://localhost:4777/api/")!

/// Any JSON value. Records are kept as loose dictionaries so fields this app doesn't know
/// (e.g. Dodo payment ids) survive an edit untouched.
enum JSON: Codable, Equatable {
    case null, bool(Bool), num(Double), str(String), arr([JSON]), obj([String: JSON])

    init(from d: Decoder) throws {
        let c = try d.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .num(n) }
        else if let s = try? c.decode(String.self) { self = .str(s) }
        else if let a = try? c.decode([JSON].self) { self = .arr(a) }
        else { self = .obj(try c.decode([String: JSON].self)) }
    }
    func encode(to e: Encoder) throws {
        var c = e.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .num(let n): try c.encode(n)
        case .str(let s): try c.encode(s)
        case .arr(let a): try c.encode(a)
        case .obj(let o): try c.encode(o)
        }
    }
    var string: String {
        switch self {
        case .str(let s): return s
        case .num(let n): return n == n.rounded() ? String(Int(n)) : String(n)
        case .bool(let b): return b ? "true" : "false"
        default: return ""
        }
    }
    var double: Double? {
        switch self {
        case .num(let n): return n
        case .str(let s): return Double(s)
        default: return nil
        }
    }
    var bool: Bool { if case .bool(let b) = self { return b }; return false }
}

enum Kind: String, CaseIterable, Identifiable {
    case tasks, domains, subs, revenue, spend, ideas, docs, goals, notes
    var id: String { rawValue }
    var noun: String { ["tasks": "Task", "domains": "Domain", "subs": "Subscription", "revenue": "Revenue", "spend": "Spending", "ideas": "Idea", "docs": "Document", "goals": "Goal", "notes": "Note"][rawValue]! }
}

struct Record: Identifiable, Equatable {
    var id: String
    var f: [String: JSON]

    subscript(_ k: String) -> String {
        get { f[k]?.string ?? "" }
        set { f[k] = .str(newValue) }
    }
    func num(_ k: String) -> Double { f[k]?.double ?? 0 }
    func flag(_ k: String) -> Bool { f[k]?.bool ?? false }
    mutating func set(_ k: String, _ v: JSON) { f[k] = v }

    func strings(_ k: String) -> [String] { if case .arr(let a) = f[k] { return a.map(\.string).filter { !$0.isEmpty } }; return [] }
    var tags: [String] { if case .arr(let a) = f["tags"] { return a.map(\.string).filter { !$0.isEmpty } }; return [] }
    var subtasks: [(t: String, d: Bool)] {
        guard case .arr(let a) = f["subtasks"] else { return [] }
        return a.compactMap { if case .obj(let o) = $0 { return (o["t"]?.string ?? "", o["d"]?.bool ?? false) }; return nil }
    }
}

/// Which sheet is open: a new record of a kind, or an existing one.
struct EditTarget: Identifiable {
    let id = UUID()
    let kind: Kind
    var record: Record?
    var file: URL? = nil
    var draft: Record? = nil
}

enum Section: String, CaseIterable, Identifiable {
    case today, tasks, goals, notes, ideas, docs, domains, subs, revenue, spend, spin
    var id: String { rawValue }
    var label: String { ["today": "Today", "tasks": "Tasks", "domains": "Domains", "subs": "Subscriptions", "revenue": "Revenue", "spend": "Spending", "ideas": "Ideas", "docs": "Documents", "goals": "Goals", "notes": "Notes", "spin": "Spin"][rawValue]! }
    var icon: String { ["today": "square.grid.2x2", "tasks": "checkmark.circle", "domains": "globe", "subs": "creditcard", "revenue": "chart.bar", "spend": "wallet.bifold", "ideas": "lightbulb", "docs": "doc.on.doc", "goals": "target", "notes": "note.text", "spin": "dial.medium"][rawValue]! }
    var kind: Kind { self == .today ? .tasks : self == .spin ? .goals : Kind(rawValue: rawValue)! }
    var newLabel: String { ["today": "New Task", "tasks": "New Task", "domains": "Add Domain", "subs": "Add Subscription", "revenue": "Add Revenue", "spend": "Add Spending", "ideas": "Add Idea", "docs": "Add Document", "goals": "New Goal", "notes": "New Note", "spin": "New Goal"][rawValue]! }
}

@MainActor
final class Store: ObservableObject {
    @Published var data: [Kind: [Record]] = [:]
    @Published var currency = "USD"
    @Published var online = false
    @Published var loaded = false
    @Published var section: Section = Section(rawValue: UserDefaults.standard.string(forKey: "section") ?? "") ?? .today {
        didSet { UserDefaults.standard.set(section.rawValue, forKey: "section") }
    }
    @Published var editing: EditTarget?
    @Published var toast: String?
    @Published var query = ""
    @Published var filesDir: URL?

    private var reloadTask: Task<Void, Never>?

    func list(_ k: Kind) -> [Record] { data[k] ?? [] }

    init() {
        Task { await load() }
        Task { await listen() }
        // Day rollover and a safety refresh.
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in Task { @MainActor in await self.load() } }
    }

    // MARK: server
    func load() async {
        do {
            let (d, r) = try await URLSession.shared.data(from: serverBase.appendingPathComponent("state"))
            guard (r as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let obj = try JSONDecoder().decode([String: JSON].self, from: d)
            var next: [Kind: [Record]] = [:]
            for k in Kind.allCases {
                guard case .arr(let rows)? = obj[k.rawValue] else { next[k] = []; continue }
                next[k] = rows.compactMap {
                    guard case .obj(var o) = $0 else { return nil }
                    let id = o["id"]?.string ?? UUID().uuidString
                    o["id"] = nil
                    return Record(id: id, f: o)
                }
            }
            data = next
            if case .obj(let s)? = obj["settings"], let c = s["currency"]?.string, !c.isEmpty { currency = c }
            online = true
            loaded = true
            if filesDir == nil, let (i, _) = try? await URLSession.shared.data(from: serverBase.appendingPathComponent("info")),
               let o = try? JSONDecoder().decode([String: String].self, from: i), let dir = o["filesDir"] { filesDir = URL(fileURLWithPath: dir) }
            updateBadge()
        } catch {
            online = false
            loaded = true
        }
    }

    /// Server-Sent Events: the server pings on every change (from this app, the web page or Claude).
    func listen() async {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 120
        cfg.timeoutIntervalForResource = .infinity
        let session = URLSession(configuration: cfg)
        while true {
            do {
                let (bytes, _) = try await session.bytes(from: serverBase.appendingPathComponent("events"))
                await load()
                for try await line in bytes.lines where line.hasPrefix("data:") { scheduleReload() }
            } catch {}
            online = false
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
    }

    private func scheduleReload() {
        reloadTask?.cancel()
        reloadTask = Task { try? await Task.sleep(nanoseconds: 150_000_000); if !Task.isCancelled { await load() } }
    }

    private func send(_ method: String, _ path: String, _ body: [String: JSON]? = nil) async -> Bool {
        var req = URLRequest(url: serverBase.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { req.httpBody = try? JSONEncoder().encode(body) }
        do {
            let (_, r) = try await URLSession.shared.data(for: req)
            return ((r as? HTTPURLResponse)?.statusCode ?? 500) < 300
        } catch { return false }
    }

    func put(_ k: Kind, _ rec: Record) {
        var arr = list(k)
        if let i = arr.firstIndex(where: { $0.id == rec.id }) { arr[i] = rec } else { arr.append(rec) }
        data[k] = arr
        updateBadge()
        Task {
            if !(await send("PUT", "\(k.rawValue)/\(rec.id)", rec.f)) { show("That change didn't save. Is the Anas HQ server running?"); await load() }
        }
    }

    func delete(_ k: Kind, _ id: String) {
        data[k] = list(k).filter { $0.id != id }
        updateBadge()
        Task {
            if !(await send("DELETE", "\(k.rawValue)/\(id)")) { show("Couldn't delete that. Is the Anas HQ server running?"); await load() }
        }
    }

    func setCurrency(_ c: String) {
        currency = c
        Task { _ = await send("PUT", "settings", ["currency": .str(c)]) }
    }

    func show(_ msg: String) {
        toast = msg
        Task { try? await Task.sleep(nanoseconds: 2_600_000_000); if toast == msg { toast = nil } }
    }

    static func newId() -> String { String(Int(Date().timeIntervalSince1970 * 1000), radix: 36) + String(UUID().uuidString.prefix(6)).lowercased() }

    // MARK: derived
    var projects: [String] {
        var seen: [String: String] = [:]
        for k in Kind.allCases { for r in list(k) { let p = r["project"].trimmingCharacters(in: .whitespaces); if !p.isEmpty { seen[p.lowercased()] = p } } }
        return seen.values.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    func values(_ k: Kind, _ field: String, base: [String] = []) -> [String] {
        Array(Set(base + list(k).map { $0[field] }.filter { !$0.isEmpty })).sorted()
    }
    /// A product's website: the first domain tagged with that project (prefers .com).
    func projectSite(_ project: String) -> String {
        guard !project.isEmpty else { return "" }
        let doms = list(.domains).filter { $0["project"].caseInsensitiveCompare(project) == .orderedSame }.map { $0["name"] }
        return doms.first { $0.hasSuffix(".com") } ?? doms.first ?? ""
    }
    var openTasks: [Record] { list(.tasks).filter { !$0.flag("done") } }
    var dueCount: Int { let t = Dates.today(); return openTasks.filter { Dates.isDate($0["due"]) && $0["due"] <= t }.count }

    func updateBadge() {
        let n = dueCount
        NSApp?.dockTile.badgeLabel = n > 0 ? "\(n)" : nil
    }

    // MARK: actions
    func toggleTask(_ t: Record) {
        var r = t
        let today = Dates.today()
        if !t.flag("done"), let rep = Optional(t["repeat"]), rep != "", rep != "none" {
            var n = Logic.step(Dates.isDate(t["due"]) ? t["due"] : today, rep)
            var guardN = 0
            while n <= today && guardN < 1000 { n = Logic.step(n, rep); guardN += 1 }
            r["due"] = n
            r["lastDone"] = today
            put(.tasks, r)
            show("Done. Next one is due \(Dates.short(n))")
        } else {
            let done = !t.flag("done")
            r.set("done", .bool(done))
            r["doneAt"] = done ? ISO8601DateFormatter().string(from: Date()) : ""
            put(.tasks, r)
            if done { show("Task completed") }
        }
    }

    /// Habits and promises: tick or untick a day.
    func toggleCheck(_ g: Record, day: String = Dates.today()) {
        var r = g
        var days = g.strings("checks")
        if let i = days.firstIndex(of: day) { days.remove(at: i) } else { days.append(day) }
        r.set("checks", .arr(days.sorted().map { .str($0) }))
        put(.goals, r)
    }

    /// Copies a file into the vault and returns the stored name.
    func storeFile(_ src: URL, id: String) -> String? {
        guard let dir = filesDir else { return nil }
        let clean = src.lastPathComponent.replacingOccurrences(of: "/", with: "-")
        let name = "\(id)-\(clean)"
        let dest = dir.appendingPathComponent(name)
        let scoped = src.startAccessingSecurityScopedResource()
        defer { if scoped { src.stopAccessingSecurityScopedResource() } }
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: dest.path) { try FileManager.default.removeItem(at: dest) }
            try FileManager.default.copyItem(at: src, to: dest)
            return name
        } catch { show("Couldn't copy that file: \(error.localizedDescription)"); return nil }
    }
    func fileURL(_ doc: Record) -> URL? {
        guard let dir = filesDir, !doc["file"].isEmpty else { return nil }
        return dir.appendingPathComponent(doc["file"])
    }

    func quickAddTask(_ text: String, defaultToday: Bool) {
        let p = Logic.parseQuick(text, projects: projects)
        guard !p.title.isEmpty else { return }
        var f: [String: JSON] = [
            "title": .str(p.title), "notes": .str(""), "project": .str(p.project),
            "due": .str(p.due.isEmpty && defaultToday ? Dates.today() : p.due),
            "pri": .str(p.pri.isEmpty ? "normal" : p.pri), "repeat": .str("none"),
            "tags": .arr([]), "subtasks": .arr([]), "done": .bool(false), "doneAt": .str(""),
        ]
        f["created"] = .str(ISO8601DateFormatter().string(from: Date()))
        put(.tasks, Record(id: Store.newId(), f: f))
        let due = f["due"]?.string ?? ""
        show("Added “\(p.title)”" + (due.isEmpty ? "" : " · \(Dates.rel(due))"))
    }

    // MARK: money
    private var fmtCache: [String: NumberFormatter] = [:]
    func money(_ n: Double, sign: Bool = false, compact: Bool = false) -> String {
        let a = abs(n)
        let dec = (a * 100).rounded().truncatingRemainder(dividingBy: 100) != 0 && !compact
        let key = currency + (dec ? "2" : "0")
        let f = fmtCache[key] ?? {
            let f = NumberFormatter()
            f.numberStyle = .currency
            f.currencyCode = currency
            f.locale = Locale(identifier: currency == "INR" ? "en_IN" : currency == "EUR" ? "en_IE" : "en_US")
            f.minimumFractionDigits = dec ? 2 : 0
            f.maximumFractionDigits = dec ? 2 : 0
            fmtCache[key] = f
            return f
        }()
        var s: String
        if compact && a >= 1000 {
            let sym = f.currencySymbol ?? "$"
            s = a >= 1_000_000 ? "\(sym)\(String(format: "%.1f", a / 1_000_000))M" : "\(sym)\(String(format: a >= 10_000 ? "%.0f" : "%.1f", a / 1000))K"
            s = s.replacingOccurrences(of: ".0K", with: "K")
        } else {
            s = f.string(from: NSNumber(value: a)) ?? String(format: "%.2f", a)
        }
        return (n < 0 ? "−" : (sign && n > 0 ? "+" : "")) + s
    }
}
