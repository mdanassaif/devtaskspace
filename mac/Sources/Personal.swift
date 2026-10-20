// Personal screens: Documents vault, Goals (goals, habits, promises to yourself), Notes & journal.
import SwiftUI
import UniformTypeIdentifiers

// MARK: Documents

let docCategories = ["Identity", "Finance", "Business", "Legal", "Health", "Education", "Other"]

struct DocsView: View {
    @EnvironmentObject var store: Store
    @AppStorage("f.dcat") private var cat = "all"
    @State private var dropping = false

    var body: some View {
        let all = store.list(.docs)
        let t0 = Dates.today(), soon = Dates.add(t0, days: 90)
        let expiring = all.filter { Dates.isDate($0["expires"]) && $0["expires"] <= soon }.sorted { $0["expires"] < $1["expires"] }
        let shown = all
            .filter { cat == "all" || ($0["category"].isEmpty ? "Other" : $0["category"]) == cat }
            .filter { hit(store.query, [$0["title"], $0["category"], $0["notes"], $0["originalName"]]) }
            .sorted { $0["title"].localizedCaseInsensitiveCompare($1["title"]) == .orderedAscending }
        let used = docCategories.filter { c in all.contains { ($0["category"].isEmpty ? "Other" : $0["category"]) == c } }

        VStack(alignment: .leading, spacing: 16) {
            if used.count > 1 {
                FilterBar(value: $cat, options: [("all", "All \(all.count)")] + used.map { c in (c, c) })
            }
            StatRow(stats: [
                Stat(label: "Documents", value: "\(all.count)", foot: "Stored on this Mac only"),
                Stat(label: "Expiring in 90 days", value: "\(expiring.count)", foot: expiring.map { $0["title"] }.joined(separator: ", "), footColor: expiring.isEmpty ? .secondary : .orange),
                Stat(label: "Next expiry", value: expiring.first.map { Dates.short($0["expires"]) } ?? "—", foot: expiring.first.map { "\($0["title"]) · \(Dates.rel($0["expires"]))" } ?? "Add expiry dates to passports, IDs, licences"),
            ])
            HStack(spacing: 12) {
                Image(systemName: "tray.and.arrow.down").font(.title3).foregroundStyle(dropping ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Drop a file here to add it").font(.callout.weight(.medium))
                    Text("PDFs, photos of IDs, contracts, invoices. A copy is kept in HQ's folder on this Mac.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Choose File…") { store.editing = EditTarget(kind: .docs) }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])).foregroundStyle(dropping ? Color.accentColor : Color(nsColor: .separatorColor)))
            Panel {
                if shown.isEmpty {
                    EmptyState(icon: "doc.on.doc", title: all.isEmpty ? "Your vault is empty" : "No documents match", text: all.isEmpty ? "Keep passport and ID scans, PAN/Aadhaar, contracts, invoices and certificates here. Add an expiry date and it shows on Today before it runs out." : "Change the filter or search.")
                }
                ForEach(Array(shown.enumerated()), id: \.element.id) { i, d in
                    if i > 0 { Divider() }
                    DocRow(d: d)
                }
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let u = urls.first else { return false }
            store.editing = EditTarget(kind: .docs, file: u)
            return true
        } isTargeted: { dropping = $0 }
    }
}

struct DocRow: View {
    @EnvironmentObject var store: Store
    let d: Record
    var body: some View {
        let url = store.fileURL(d)
        let exists = url.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        let n = Dates.isDate(d["expires"]) ? Dates.diff(d["expires"], Dates.today()) : nil
        Row(kind: .docs, record: d, title: d["title"].isEmpty ? d["originalName"] : d["title"],
            subtitle: [d["category"].isEmpty ? "Other" : d["category"], exists ? d["originalName"] : "File missing"].filter { !$0.isEmpty },
            whenMain: n == nil ? "" : Dates.short(d["expires"]),
            whenSub: n == nil ? "" : (n! < 0 ? "Expired \(Dates.rel(d["expires"]))" : "Expires \(Dates.rel(d["expires"]))"),
            whenColor: n == nil ? .primary : n! < 0 ? .red : n! <= 90 ? .orange : .primary) {
            Image(nsImage: exists ? NSWorkspace.shared.icon(forFile: url!.path) : NSWorkspace.shared.icon(for: .data))
                .resizable().frame(width: 30, height: 30)
        } meta: {
            if exists {
                HStack(spacing: 12) {
                    Button { NSWorkspace.shared.open(url!) } label: { Image(systemName: "eye") }.help("Open")
                    Button { NSWorkspace.shared.activateFileViewerSelecting([url!]) } label: { Image(systemName: "folder") }.help("Show in Finder")
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: Goals, habits, promises

enum GoalType: String, CaseIterable {
    case goal, habit, promise
    var label: String { ["goal": "Goal", "habit": "Habit", "promise": "Promise to myself"][rawValue]! }
    var plural: String { ["goal": "Goals", "habit": "Habits", "promise": "Promises"][rawValue]! }
    var icon: String { ["goal": "target", "habit": "repeat", "promise": "hand.raised"][rawValue]! }
    var color: Color { switch self { case .goal: .indigo; case .habit: .teal; case .promise: .pink } }
}

extension Logic {
    /// Days in a row ending today (or yesterday, if today isn't ticked yet).
    static func streak(_ days: [String]) -> Int {
        let set = Set(days), t0 = Dates.today()
        var d = set.contains(t0) ? t0 : Dates.add(t0, days: -1), n = 0
        while set.contains(d) { n += 1; d = Dates.add(d, days: -1) }
        return n
    }
}

struct GoalsView: View {
    @EnvironmentObject var store: Store
    @AppStorage("f.gtype") private var type = "all"
    @AppStorage("f.gstat") private var stat = "active"
    @State private var text = ""
    @State private var addType = GoalType.goal

    var body: some View {
        let all = store.list(.goals)
        let active = all.filter { ($0["status"].isEmpty ? "active" : $0["status"]) == "active" }
        let shown = all
            .filter { type == "all" || $0["type"] == type }
            .filter { stat == "all" || ($0["status"].isEmpty ? "active" : $0["status"]) == stat }
            .filter { hit(store.query, [$0["title"], $0["notes"], $0["why"]]) }
        let t0 = Dates.today()
        let daily = active.filter { $0["type"] != "goal" }
        let keptToday = daily.filter { $0.strings("checks").contains(t0) }.count
        let goals = active.filter { $0["type"] == "goal" && $0.num("target") > 0 }
        let avg = goals.isEmpty ? 0 : goals.map { min(1, $0.num("current") / $0.num("target")) }.reduce(0, +) / Double(goals.count)
        let best = daily.map { ($0["title"], Logic.streak($0.strings("checks"))) }.max { $0.1 < $1.1 }

        VStack(alignment: .leading, spacing: 16) {
            HStack {
                FilterBar(value: $type, options: [("all", "All")] + GoalType.allCases.map { ($0.rawValue, $0.plural) })
                Spacer()
                FilterBar(value: $stat, options: [("active", "Active"), ("done", "Achieved"), ("all", "All")])
            }
            StatRow(stats: [
                Stat(label: "Kept today", value: "\(keptToday)/\(daily.count)", foot: daily.isEmpty ? "Add a habit or a promise" : keptToday == daily.count ? "Everything kept today" : "\(daily.count - keptToday) still to do", footColor: !daily.isEmpty && keptToday == daily.count ? .green : .secondary),
                Stat(label: "Best streak", value: best.map { "\($0.1) days" } ?? "—", foot: best?.0 ?? ""),
                Stat(label: "Goal progress", value: goals.isEmpty ? "—" : "\(Int((avg * 100).rounded()))%", foot: "Average across \(goals.count) active goals"),
                Stat(label: "Achieved", value: "\(all.filter { $0["status"] == "done" }.count)", foot: "Goals and promises completed"),
            ])
            HStack(spacing: 10) {
                Image(systemName: "plus").foregroundStyle(.secondary)
                TextField(addType == .promise ? "I promise myself… e.g. “No phone before 10am”" : addType == .habit ? "New habit… e.g. “Walk 30 minutes”" : "New goal… e.g. “Reach $5K MRR”", text: $text)
                    .textFieldStyle(.plain)
                    .onSubmit(add)
                Picker("", selection: $addType) {
                    ForEach(GoalType.allCases, id: \.self) { Label($0.label, systemImage: $0.icon).tag($0) }
                }
                .labelsHidden().fixedSize()
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .card()
            .onChange(of: type) { _, t in if let g = GoalType(rawValue: t) { addType = g } }
            Panel {
                if shown.isEmpty {
                    EmptyState(icon: "target", title: all.isEmpty ? "Set your first goal" : "Nothing here",
                               text: all.isEmpty ? "Goals have a number to reach. Habits and promises to yourself get a tick each day you keep them, and build a streak." : "Switch the filter above.")
                }
                ForEach(GoalType.allCases, id: \.self) { g in
                    let items = shown.filter { ($0["type"].isEmpty ? "goal" : $0["type"]) == g.rawValue }.sorted { $0["created"] < $1["created"] }
                    if !items.isEmpty {
                        GroupHeader(title: g.plural, right: "\(items.count)")
                        ForEach(items) { r in
                            Divider()
                            if g == .goal { GoalRow(g: r) } else { HabitRow(g: r) }
                        }
                    }
                }
            }
        }
    }

    private func add() {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        var f: [String: JSON] = ["title": .str(t), "type": .str(addType.rawValue), "status": .str("active"), "notes": .str(""), "why": .str("")]
        if addType == .goal { f["target"] = .str(""); f["current"] = .num(0); f["unit"] = .str(""); f["due"] = .str("") }
        else { f["checks"] = .arr([]); f["since"] = .str(Dates.today()) }
        f["created"] = .str(ISO8601DateFormatter().string(from: Date()))
        let rec = Record(id: Store.newId(), f: f)
        store.put(.goals, rec)
        text = ""
        // Goals need a target, so open the editor straight away.
        if addType == .goal { store.editing = EditTarget(kind: .goals, record: rec) }
    }
}

struct GoalRow: View {
    @EnvironmentObject var store: Store
    let g: Record
    var body: some View {
        let target = g.num("target"), cur = g.num("current")
        let p = target > 0 ? min(1, cur / target) : 0
        let done = g["status"] == "done"
        let fmt = { (n: Double) in n == n.rounded() ? String(Int(n)) : String(format: "%.1f", n) }
        Row(kind: .goals, record: g, title: g["title"], subtitle: [g["why"]].filter { !$0.isEmpty },
            whenMain: Dates.isDate(g["due"]) ? Dates.short(g["due"]) : "", whenSub: Dates.isDate(g["due"]) ? Dates.rel(g["due"]) : "", dim: done) {
            Image(systemName: done ? "checkmark.seal.fill" : "target")
                .foregroundStyle(done ? Color.green : GoalType.goal.color)
                .frame(width: 30, height: 30)
                .background(Circle().fill((done ? Color.green : GoalType.goal.color).opacity(0.13)))
        } meta: {
            HStack(spacing: 12) {
                if target > 0 {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(fmt(cur)) / \(fmt(target)) \(g["unit"])").font(.callout).monospacedDigit()
                        ProgressView(value: p).frame(width: 160).tint(p >= 1 ? .green : GoalType.goal.color)
                    }
                    if !done {
                        Button {
                            var r = g
                            r.set("current", .num(cur + 1))
                            if cur + 1 >= target { r["status"] = "done"; store.show("Goal achieved: \(g["title"])") }
                            store.put(.goals, r)
                        } label: { Image(systemName: "plus.circle") }
                            .buttonStyle(.plain).foregroundStyle(.secondary).help("Add 1")
                    }
                } else {
                    Text("Set a target").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct HabitRow: View {
    @EnvironmentObject var store: Store
    let g: Record
    var body: some View {
        let t = GoalType(rawValue: g["type"]) ?? .habit
        let checks = Set(g.strings("checks")), t0 = Dates.today()
        let streak = Logic.streak(Array(checks))
        let kept = checks.contains(t0)
        let days = (0..<7).reversed().map { Dates.add(t0, days: -$0) }
        let sinceDays = Dates.isDate(g["since"]) ? Dates.diff(t0, g["since"]) + 1 : 0
        Row(kind: .goals, record: g, title: g["title"],
            subtitle: [t == .promise ? "Kept \(checks.count) of \(max(sinceDays, checks.count)) days" : "\(checks.count) days done", g["why"]].filter { !$0.isEmpty },
            whenMain: streak > 0 ? "\(streak)-day" : "", whenSub: streak > 0 ? "streak" : "No streak yet", whenColor: streak >= 3 ? .green : .primary,
            dim: g["status"] == "done") {
            Button { store.toggleCheck(g) } label: {
                Image(systemName: kept ? "checkmark.circle.fill" : t.icon)
                    .font(.system(size: kept ? 18 : 14))
                    .foregroundStyle(kept ? Color.green : t.color)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill((kept ? Color.green : t.color).opacity(0.13)))
            }
            .buttonStyle(.plain)
            .help(kept ? "Untick today" : (t == .promise ? "I kept it today" : "Done today"))
        } meta: {
            HStack(spacing: 5) {
                ForEach(days, id: \.self) { d in
                    Button { store.toggleCheck(g, day: d) } label: {
                        VStack(spacing: 3) {
                            Circle().fill(checks.contains(d) ? Color.green : Color.primary.opacity(0.08)).frame(width: 14, height: 14)
                            Text(String(Dates.day(d).prefix(1))).font(.system(size: 9)).foregroundStyle(d == t0 ? .primary : .tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .help(Dates.day(d))
                }
            }
        }
    }
}

// MARK: Notes & journal

struct NotesView: View {
    @EnvironmentObject var store: Store
    @AppStorage("f.ntype") private var type = "journal"
    @State private var title = ""

    var body: some View {
        let all = store.list(.notes)
        let shown = all.filter { ($0["type"].isEmpty ? "note" : $0["type"]) == type }
            .filter { hit(store.query, [$0["title"], $0["body"], $0.tags.joined(separator: " ")]) }
        let journalDays = all.filter { $0["type"] == "journal" }.map { $0["date"] }

        VStack(alignment: .leading, spacing: 16) {
            HStack {
                FilterBar(value: $type, options: [("journal", "Journal"), ("note", "Notes")])
                Spacer()
                if type == "journal" {
                    let s = Logic.streak(journalDays)
                    Text(s > 1 ? "\(s)-day writing streak" : "\(journalDays.count) entries").font(.callout).foregroundStyle(.secondary)
                }
            }
            if type == "journal" {
                JournalToday()
                let past = shown.filter { $0["date"] != Dates.today() }.sorted { $0["date"] > $1["date"] }
                if !past.isEmpty {
                    Text("EARLIER").font(.caption.weight(.semibold)).tracking(0.6).foregroundStyle(.secondary).padding(.horizontal, 2)
                    Panel {
                        ForEach(Array(past.enumerated()), id: \.element.id) { i, n in
                            if i > 0 { Divider() }
                            Row(kind: .notes, record: n, title: Dates.day(n["date"]), subtitle: [preview(n["body"])], whenSub: Dates.rel(n["date"])) {
                                Image(systemName: "book.closed").foregroundStyle(.orange).frame(width: 30, height: 30).background(Circle().fill(Color.orange.opacity(0.12)))
                            } meta: { EmptyView() }
                        }
                    }
                }
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "plus").foregroundStyle(.secondary)
                    TextField("New note title, then press Return to write", text: $title)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            let t = title.trimmingCharacters(in: .whitespaces)
                            guard !t.isEmpty else { return }
                            var b = Editor.blank(.notes)
                            b["title"] = t
                            store.editing = EditTarget(kind: .notes, draft: b)
                            title = ""
                        }
                }
                .padding(.horizontal, 14).padding(.vertical, 11)
                .card()
                Panel {
                    if shown.isEmpty {
                        EmptyState(icon: "note.text", title: all.contains { $0["type"] != "journal" } ? "No notes match" : "No notes yet", text: "Ideas, meeting notes, how-tos, things to remember. Pin the important ones to keep them on top.")
                    }
                    let sorted = shown.sorted { a, b in
                        if a.flag("pinned") != b.flag("pinned") { return a.flag("pinned") }
                        return (a["updated"].isEmpty ? a["created"] : a["updated"]) > (b["updated"].isEmpty ? b["created"] : b["updated"])
                    }
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { i, n in
                        if i > 0 { Divider() }
                        let when = Dates.isoDay(n["updated"].isEmpty ? n["created"] : n["updated"])
                        Row(kind: .notes, record: n, title: n["title"].isEmpty ? "Untitled" : n["title"], subtitle: [preview(n["body"])].filter { !$0.isEmpty },
                            whenMain: Dates.short(when), whenSub: n.flag("pinned") ? "Pinned" : "") {
                            Image(systemName: n.flag("pinned") ? "pin.fill" : "note.text").foregroundStyle(.indigo).frame(width: 30, height: 30).background(Circle().fill(Color.indigo.opacity(0.12)))
                        } meta: {
                            HStack(spacing: 6) {
                                ForEach(n.tags.prefix(3), id: \.self) { Text($0).font(.caption).padding(.horizontal, 7).padding(.vertical, 2).overlay(Capsule().strokeBorder(Color(nsColor: .separatorColor))) }
                            }
                        }
                    }
                }
            }
        }
    }

    private func preview(_ s: String) -> String {
        s.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
    }
}

/// Today's journal entry, typed straight into the page and saved as you write.
struct JournalToday: View {
    @EnvironmentObject var store: Store
    @State private var text = ""
    @State private var loadedFor = ""
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        let t0 = Dates.today()
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(Dates.day(t0)).font(.headline)
                Text("Today").font(.callout).foregroundStyle(.secondary)
                Spacer()
                Text(text.isEmpty ? "What did you ship, learn or feel today?" : "Saved").font(.caption).foregroundStyle(.secondary)
            }
            TextEditor(text: $text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 160)
                .onChange(of: text) { _, v in
                    guard loadedFor == t0 else { return }
                    saveTask?.cancel()
                    saveTask = Task { try? await Task.sleep(nanoseconds: 700_000_000); if !Task.isCancelled { save(v) } }
                }
        }
        .padding(16)
        .card()
        .onAppear(perform: load)
        .onChange(of: store.list(.notes).count) { _, _ in if loadedFor != t0 { load() } }
    }

    private var entry: Record? { store.list(.notes).first { $0["type"] == "journal" && $0["date"] == Dates.today() } }

    private func load() {
        text = entry?["body"] ?? ""
        loadedFor = Dates.today()
    }

    private func save(_ v: String) {
        var r = entry ?? {
            var b = Editor.blank(.notes)
            b["type"] = "journal"; b["date"] = Dates.today(); b["title"] = "Journal · \(Dates.day(Dates.today()))"
            b["created"] = ISO8601DateFormatter().string(from: Date())
            return b
        }()
        guard r["body"] != v else { return }
        r["body"] = v
        r["updated"] = ISO8601DateFormatter().string(from: Date())
        store.put(.notes, r)
    }
}
