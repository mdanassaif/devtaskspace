// The seven screens: Today, Tasks, Domains, Subscriptions, Revenue, Spending, Ideas.
import SwiftUI

// MARK: rows shared by several screens

struct TaskRow: View {
    @EnvironmentObject var store: Store
    let t: Record

    private var subtitle: [String] {
        var out: [String] = []
        let s = t.subtasks
        if !s.isEmpty { out.append("\(s.filter(\.d).count)/\(s.count) steps") }
        if let line = t["notes"].split(separator: "\n").first { out.append(String(line)) }
        return out
    }
    private var when: (String, String) {
        if t.flag("done") { return ("Done", Dates.short(Dates.isoDay(t["doneAt"]))) }
        if Dates.isDate(t["due"]) { return (Dates.short(t["due"]), Dates.rel(t["due"])) }
        return ("", "No date")
    }

    var body: some View {
        let p = Logic.pri(t), done = t.flag("done"), late = !done && Logic.bucket(t) == .overdue
        Row(kind: .tasks, record: t, title: t["title"].isEmpty ? "Untitled task" : t["title"], subtitle: subtitle, project: t["project"],
            whenMain: when.0, whenSub: when.1, whenColor: late ? .red : .primary, dim: done) {
            Button { store.toggleTask(t) } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(done ? Color.green : (p == .normal ? Color.secondary : p.color))
            }
            .buttonStyle(.plain)
            .help(done ? "Mark as not done" : "Mark as done")
        } meta: {
            HStack(spacing: 8) {
                ForEach(t.tags.prefix(3), id: \.self) { tag in
                    Text(tag).font(.caption).padding(.horizontal, 7).padding(.vertical, 2)
                        .overlay(Capsule().strokeBorder(Color(nsColor: .separatorColor)))
                }
                if !t["repeat"].isEmpty && t["repeat"] != "none" {
                    Label(t["repeat"].capitalized, systemImage: "repeat").font(.caption).foregroundStyle(.secondary)
                }
                if !done && (p == .urgent || p == .high) { Pill(label: p.label, color: p.color) }
            }
        }
    }
}

struct Renewal: Identifiable {
    let kind: Kind
    let rec: Record
    let date: String
    var id: String { kind.rawValue + rec.id }
}

@MainActor func renewals(_ store: Store, days: Int) -> [Renewal] {
    let limit = Dates.add(Dates.today(), days: days)
    let doms = store.list(.domains).filter { !$0.flag("parked") && Dates.isDate($0["expires"]) && $0["expires"] <= limit }
        .map { Renewal(kind: .domains, rec: $0, date: $0["expires"]) }
    let subs = store.list(.subs).compactMap { s -> Renewal? in
        let n = Logic.subNext(s)
        return !n.isEmpty && n <= limit ? Renewal(kind: .subs, rec: s, date: n) : nil
    }
    let docs = store.list(.docs).filter { Dates.isDate($0["expires"]) && $0["expires"] <= limit }
        .map { Renewal(kind: .docs, rec: $0, date: $0["expires"]) }
    return (doms + subs + docs).sorted { $0.date < $1.date }
}

struct RenewalRow: View {
    @EnvironmentObject var store: Store
    let r: Renewal
    var body: some View {
        let isDom = r.kind == .domains, isDoc = r.kind == .docs
        let n = Dates.diff(r.date, Dates.today())
        let amount = isDoc ? "" : isDom ? (r.rec.num("cost") > 0 ? store.money(r.rec.num("cost")) + "/yr" : "") : store.money(r.rec.num("amount")) + (cycles[r.rec["cycle"]] ?? "/mo")
        let note = isDoc ? r.rec["category"] : isDom ? (r.rec.flag("autoRenew") ? "Auto-renew" : "Manual renewal") : r.rec["plan"]
        Row(kind: r.kind, record: r.rec, title: isDoc ? r.rec["title"] : r.rec["name"], subtitle: [isDoc ? "Document" : isDom ? "Domain" : "Subscription"] + (note.isEmpty ? [] : [note]),
            whenMain: Dates.short(r.date), whenSub: n < 0 ? "Expired \(Dates.rel(r.date))" : Dates.rel(r.date),
            whenColor: n < 0 ? .red : n <= 7 ? .orange : .primary) {
            SiteIcon(site: isDoc ? "" : isDom ? r.rec["name"] : Favicons.site(forSub: r.rec), name: isDoc ? r.rec["title"] : r.rec["name"])
        } meta: {
            Text(amount).font(.callout).monospacedDigit()
        }
    }
}

// MARK: Today

struct TodayView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let t0 = Dates.today()
        let open = store.openTasks.filter { hit(store.query, [$0["title"], $0["project"], $0["notes"]]) }
        let overdue = open.filter { Logic.bucket($0) == .overdue }.sorted(by: Logic.taskSort)
        let today = open.filter { Logic.bucket($0) == .today }.sorted(by: Logic.taskSort)
        let next = open.filter { [.tomorrow, .week].contains(Logic.bucket($0)) }.sorted(by: Logic.taskSort).prefix(4)
        let rev = store.list(.revenue)
        let pts = dailyPoints(rev, dateField: "date", days: 30)
        let tot = Logic.r2(pts.map(\.value).reduce(0, +))
        let revToday = rev.filter { $0["date"] == t0 }.map { $0.num("amount") }.reduce(0, +)
        let revYday = rev.filter { $0["date"] == Dates.add(t0, days: -1) }.map { $0.num("amount") }.reduce(0, +)
        let live = store.list(.subs).filter(Logic.isLive)
        let burn = live.map(Logic.monthly).reduce(0, +)
        let ren = renewals(store, days: 30)

        VStack(alignment: .leading, spacing: 16) {
            TodayHero()
            QuickAdd(placeholder: "Add a task for today… or type a date like “fri”, “oct 25”, “in 3d”", defaultToday: true)
            StatRow(stats: [
                Stat(label: "Revenue today", value: store.money(revToday), foot: "Yesterday \(store.money(revYday))"),
                Stat(label: "Last 30 days", value: store.money(tot), foot: "\(pts.filter { $0.value != 0 }.count) days with sales"),
                Stat(label: "Open tasks", value: "\(store.openTasks.count)", foot: overdue.isEmpty ? "\(today.count) due today" : "\(overdue.count) overdue · \(today.count) due today", footColor: overdue.isEmpty ? .secondary : .red),
                Stat(label: "Monthly burn", value: store.money(burn) + "/mo", foot: "\(ren.count) renewals in 30 days", footColor: ren.contains { Dates.diff($0.date, t0) <= 7 } ? .orange : .secondary),
            ])
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    sectionTitle("Focus", link: "All tasks", to: .tasks)
                    Panel {
                        if overdue.isEmpty && today.isEmpty {
                            EmptyLine(icon: "checkmark.circle", text: next.isEmpty ? "Nothing due today" : "Nothing due today · up next below")
                            if !next.isEmpty {
                                GroupHeader(title: "Up next", right: "\(next.count)")
                                ForEach(Array(next)) { t in Divider(); TaskRow(t: t) }
                            }
                        } else {
                            if !overdue.isEmpty {
                                GroupHeader(title: "Overdue", right: "\(overdue.count)", color: .red)
                                ForEach(overdue) { t in Divider(); TaskRow(t: t) }
                            }
                            if !today.isEmpty {
                                GroupHeader(title: "Today", right: "\(today.count)")
                                ForEach(today) { t in Divider(); TaskRow(t: t) }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 8) {
                    sectionTitle("Renewals · 30 days", link: "Domains", to: .domains)
                    Panel {
                        if ren.isEmpty {
                            EmptyLine(icon: "arrow.triangle.2.circlepath", text: "No renewals in the next 30 days")
                        } else {
                            ForEach(Array(ren.enumerated()), id: \.element.id) { i, r in
                                if i > 0 { Divider() }
                                RenewalRow(r: r)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            let daily = store.list(.goals).filter { $0["type"] != "goal" && ($0["status"].isEmpty || $0["status"] == "active") }
            if !daily.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    sectionTitle("Habits & promises · today", link: "Goals", to: .goals)
                    Panel {
                        ForEach(Array(daily.sorted { $0["created"] < $1["created"] }.enumerated()), id: \.element.id) { i, g in
                            if i > 0 { Divider() }
                            HabitRow(g: g)
                        }
                    }
                }
            }
            BarChart(title: "Daily revenue · 30 days", total: store.money(tot), points: pts, height: 120)
        }
    }

    private func sectionTitle(_ t: String, link: String, to: Section) -> some View {
        HStack {
            Text(t.uppercased()).font(.caption.weight(.semibold)).tracking(0.6).foregroundStyle(.secondary)
            Spacer()
            Button(link) { store.section = to }.buttonStyle(.link).font(.callout)
        }
        .padding(.horizontal, 2)
    }
}

// MARK: Tasks

struct TasksView: View {
    @EnvironmentObject var store: Store
    @AppStorage("f.when") private var when = "all"
    @AppStorage("f.pri") private var pri = "any"

    var body: some View {
        let all = store.list(.tasks).filter { hit(store.query, [$0["title"], $0["project"], $0["notes"], $0.tags.joined(separator: " ")]) }
        let open = all.filter { !$0.flag("done") }
        let t0 = Dates.today()
        let shown: [Record] = {
            var l: [Record]
            switch when {
            case "today": l = open.filter { Dates.isDate($0["due"]) && $0["due"] <= t0 }
            case "upcoming": l = open.filter { Dates.isDate($0["due"]) && $0["due"] > t0 }
            case "overdue": l = open.filter { Logic.bucket($0) == .overdue }
            case "nodate": l = open.filter { !Dates.isDate($0["due"]) }
            case "done": l = all.filter { $0.flag("done") }
            default: l = open
            }
            if pri != "any" { l = l.filter { Logic.pri($0).rawValue == pri } }
            return l
        }()
        let od = open.filter { Logic.bucket($0) == .overdue }.count

        VStack(alignment: .leading, spacing: 16) {
            HStack {
                FilterBar(value: $when, options: [("all", "All open \(open.count)"), ("today", "Today"), ("upcoming", "Upcoming"), ("overdue", od > 0 ? "Overdue \(od)" : "Overdue"), ("nodate", "No date"), ("done", "Done")])
                Spacer()
                Picker("Priority", selection: $pri) {
                    Text("Any priority").tag("any")
                    ForEach(Pri.allCases, id: \.self) { Text($0.label).tag($0.rawValue) }
                }
                .labelsHidden().fixedSize()
            }
            QuickAdd(placeholder: "Add a task… try “Renew SSL tomorrow #trustseo !high”", defaultToday: false)
            Panel {
                if shown.isEmpty {
                    EmptyState(icon: "checkmark.circle", title: store.list(.tasks).isEmpty ? "No tasks yet" : (open.isEmpty && when != "done" ? "All clear" : "Nothing here"), text: store.list(.tasks).isEmpty ? "Type one in the box above. Dates like “tomorrow” or “fri”, #project and !high fill themselves in." : (open.isEmpty && when != "done" ? "Every task is done. Add the next one above." : "Switch the filter above, or add a task."))
                } else if when == "done" {
                    ForEach(Array(shown.sorted { $0["doneAt"] > $1["doneAt"] }.enumerated()), id: \.element.id) { i, t in
                        if i > 0 { Divider() }
                        TaskRow(t: t)
                    }
                } else {
                    ForEach(Bucket.allCases, id: \.self) { b in
                        let items = shown.filter { Logic.bucket($0) == b }.sorted(by: Logic.taskSort)
                        if !items.isEmpty {
                            GroupHeader(title: b.label, right: "\(items.count)", color: b == .overdue ? .red : .secondary)
                            ForEach(items) { t in Divider(); TaskRow(t: t) }
                        }
                    }
                }
            }
            if when != "done" { TaskProgress() }
        }
    }
}

/// Achievement strip: how much got done, streak, and the latest completions.
struct TaskProgress: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let tasks = store.list(.tasks)
        // A completed task counts on the day it was ticked; a repeating task counts on its last completion.
        let days: [String] = tasks.compactMap { t in
            if t.flag("done") && !t["doneAt"].isEmpty { return Dates.isoDay(t["doneAt"]) }
            if Dates.isDate(t["lastDone"]) { return t["lastDone"] }
            return nil
        }
        let t0 = Dates.today()
        let week = Dates.add(t0, days: -6), month = String(t0.prefix(7))
        let done = tasks.filter { $0.flag("done") }.sorted { $0["doneAt"] > $1["doneAt"] }
        let streak: Int = {
            let set = Set(days)
            var d = set.contains(t0) ? t0 : Dates.add(t0, days: -1), n = 0
            while set.contains(d) { n += 1; d = Dates.add(d, days: -1) }
            return n
        }()

        if !days.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("PROGRESS").font(.caption.weight(.semibold)).tracking(0.6).foregroundStyle(.secondary).padding(.horizontal, 2).padding(.top, 8)
                StatRow(stats: [
                    Stat(label: "Done today", value: "\(days.filter { $0 == t0 }.count)", foot: "Yesterday \(days.filter { $0 == Dates.add(t0, days: -1) }.count)"),
                    Stat(label: "This week", value: "\(days.filter { $0 >= week }.count)", foot: "Last 7 days"),
                    Stat(label: "This month", value: "\(days.filter { $0.hasPrefix(month) }.count)", foot: Dates.month(month)),
                    Stat(label: "All time", value: "\(days.count)", foot: streak > 1 ? "\(streak)-day streak" : streak == 1 ? "1 day in a row" : "Finish one today to start a streak", footColor: streak > 1 ? .green : .secondary),
                ])
                if !done.isEmpty {
                    Text("RECENTLY COMPLETED").font(.caption.weight(.semibold)).tracking(0.6).foregroundStyle(.secondary).padding(.horizontal, 2).padding(.top, 8)
                    Panel {
                        ForEach(Array(done.prefix(5).enumerated()), id: \.element.id) { i, t in
                            if i > 0 { Divider() }
                            TaskRow(t: t)
                        }
                    }
                }
            }
        }
    }
}

// MARK: Domains

struct DomainsView: View {
    @EnvironmentObject var store: Store
    @AppStorage("f.dstat") private var stat = "all"
    @AppStorage("f.reg") private var reg = "all"
    @AppStorage("f.live") private var live = "all"
    @ObservedObject private var site = SiteStatus.shared

    var body: some View {
        let all = store.list(.domains)
        let liveCount = all.filter { site.state($0["name"]) == .live }.count
        let downCount = all.filter { site.state($0["name"]) == .down }.count
        let regs = Array(Set(all.map { $0["registrar"] }.filter { !$0.isEmpty })).sorted()
        let count = { (s: DomStatus) in all.filter { Logic.domStatus($0) == s }.count }
        let shown = all
            .filter { stat == "all" || Logic.domStatus($0).rawValue == stat }
            .filter { reg == "all" || $0["registrar"] == reg }
            .filter { live == "all" || (live == "live" ? site.state($0["name"]) == .live : site.state($0["name"]) == .down) }
            .filter { hit(store.query, [$0["name"], $0["project"], $0["registrar"], $0["dns"], $0["notes"]]) }
            .sorted { ($0["expires"].isEmpty ? "9999" : $0["expires"]) < ($1["expires"].isEmpty ? "9999" : $1["expires"]) }
        let soon = all.filter { Logic.domStatus($0) == .expiring }.sorted { $0["expires"] < $1["expires"] }
        let yearly = all.filter { !$0.flag("parked") }.map { $0.num("cost") }.reduce(0, +)
        let next = all.filter { !$0.flag("parked") && Dates.isDate($0["expires"]) && $0["expires"] >= Dates.today() }.min { $0["expires"] < $1["expires"] }

        VStack(alignment: .leading, spacing: 16) {
            HStack {
                FilterBar(value: $stat, options: [("all", "All \(all.count)")] + DomStatus.allCases.map { ($0.rawValue, count($0) > 0 && $0 != .active ? "\($0.label) \(count($0))" : $0.label) })
                Spacer()
                Picker("Site", selection: $live) {
                    Text("Any site").tag("all")
                    Text("Live \(liveCount)").tag("live")
                    Text("Down \(downCount)").tag("down")
                }
                .labelsHidden().fixedSize()
                if regs.count > 1 {
                    Picker("Registrar", selection: $reg) {
                        Text("Any registrar").tag("all")
                        ForEach(regs, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden().fixedSize()
                }
            }
            StatRow(stats: [
                Stat(label: "Domains", value: "\(all.count)", foot: liveCount + downCount == 0 ? "Checking sites…" : "\(liveCount) live · \(downCount) down", footColor: downCount > 0 ? .orange : .secondary),
                Stat(label: "Expiring in 30 days", value: "\(soon.count)", foot: soon.map { $0["name"] }.joined(separator: ", "), footColor: soon.isEmpty ? .secondary : .orange),
                Stat(label: "Renewals per year", value: store.money(yearly), foot: yearly > 0 ? "\(store.money(yearly / 12)) a month" : "Add prices to see this"),
                Stat(label: "Next expiry", value: next.map { Dates.short($0["expires"]) } ?? "—", foot: next.map { "\($0["name"]) · \(Dates.rel($0["expires"]))" } ?? ""),
            ])
            Panel {
                if shown.isEmpty {
                    EmptyState(icon: "globe", title: all.isEmpty ? "No domains yet" : "No domains match", text: all.isEmpty ? "Add a domain with its expiry date and it shows on Today a month before it renews." : "Change the filter or search.")
                }
                ForEach(Array(shown.enumerated()), id: \.element.id) { i, d in
                    if i > 0 { Divider() }
                    DomainRow(d: d)
                }
            }
        }
    }
}

struct DomainRow: View {
    @EnvironmentObject var store: Store
    @ObservedObject private var site = SiteStatus.shared
    let d: Record
    var body: some View {
        let st = Logic.domStatus(d)
        let n = Dates.isDate(d["expires"]) ? Dates.diff(d["expires"], Dates.today()) : nil
        Row(kind: .domains, record: d, title: d["name"], subtitle: [d["registrar"].isEmpty ? "No registrar set" : d["registrar"]], project: d["project"],
            whenMain: n == nil ? "" : Dates.short(d["expires"]),
            whenSub: n == nil ? "No expiry set" : (n! < 0 ? "Expired \(Dates.rel(d["expires"]))" : Dates.rel(d["expires"])),
            whenColor: n == nil ? .primary : n! < 0 ? .red : n! <= 30 ? .orange : .primary) {
            SiteIcon(site: d["name"], name: d["name"], key: d["project"].isEmpty ? d["name"] : d["project"])
        } meta: {
            HStack(spacing: 12) {
                switch site.state(d["name"]) {
                case .live: Label("Live", systemImage: "circle.fill").labelStyle(DotLabel(color: .green))
                case .down: Label("Down", systemImage: "circle.fill").labelStyle(DotLabel(color: .red)).help("The website didn't load")
                case nil: Text("Checking…").foregroundStyle(.tertiary)
                }
                if d.flag("autoRenew") {
                    Label("Auto-renew", systemImage: "arrow.triangle.2.circlepath").foregroundStyle(.green)
                } else {
                    Label("Manual", systemImage: "arrow.triangle.2.circlepath").foregroundStyle(n != nil && n! <= 30 && !d.flag("parked") ? .orange : .secondary)
                }
                if d.num("cost") > 0 { Text(store.money(d.num("cost")) + "/yr").monospacedDigit() }
                if st != .active { Pill(label: st == .expiring ? "Expiring" : st.label, color: st.color) }
                Button { NSWorkspace.shared.open(URL(string: "https://" + d["name"])!) } label: { Image(systemName: "arrow.up.right.square") }
                    .buttonStyle(.plain).foregroundStyle(.secondary).help("Open \(d["name"])")
            }
            .font(.callout)
        }
    }
}

// MARK: Subscriptions

struct SubsView: View {
    @EnvironmentObject var store: Store
    @AppStorage("f.sstat") private var stat = "all"

    var body: some View {
        let all = store.list(.subs)
        let live = all.filter(Logic.isLive)
        let burn = live.map(Logic.monthly).reduce(0, +)
        let shown = all
            .filter { stat == "all" || Logic.subStatus($0).rawValue == stat }
            .filter { hit(store.query, [$0["name"], $0["plan"], $0["project"], $0["category"], $0["notes"]]) }
            .sorted {
                let a = Logic.subNext($0), b = Logic.subNext($1)
                if a.isEmpty != b.isEmpty { return !a.isEmpty }
                return a == b ? $0["name"] < $1["name"] : a < b
            }
        let next = live.map { ($0, Logic.subNext($0)) }.filter { !$0.1.isEmpty }.min { $0.1 < $1.1 }
        let biggest = live.max { Logic.monthly($0) < Logic.monthly($1) }

        VStack(alignment: .leading, spacing: 16) {
            FilterBar(value: $stat, options: [("all", "All \(all.count)")] + SubStatus.allCases.map { s in (s.rawValue, "\(s.label) \(all.filter { Logic.subStatus($0) == s }.count)") })
            StatRow(stats: [
                Stat(label: "Monthly burn", value: store.money(burn) + "/mo", foot: "\(live.filter { Logic.subStatus($0) == .active }.count) active · \(live.filter { Logic.subStatus($0) == .trial }.count) trial"),
                Stat(label: "Per year", value: store.money(burn * 12), foot: "At current plans"),
                Stat(label: "Next charge", value: next.map { store.money($0.0.num("amount")) } ?? "—", foot: next.map { "\($0.0["name"]) · \(Dates.rel($0.1))" } ?? "Add billing dates to see this"),
                Stat(label: "Biggest cost", value: biggest?["name"] ?? "—", foot: biggest.map { "\(store.money(Logic.monthly($0)))/mo · \(burn > 0 ? Int((Logic.monthly($0) / burn * 100).rounded()) : 0)% of burn" } ?? ""),
            ])
            Panel {
                if shown.isEmpty {
                    EmptyState(icon: "creditcard", title: all.isEmpty ? "No subscriptions yet" : "No subscriptions match", text: all.isEmpty ? "Add the tools you pay for with their next billing date." : "Change the filter or search.")
                }
                ForEach(Array(shown.enumerated()), id: \.element.id) { i, s in
                    if i > 0 { Divider() }
                    SubRow(s: s)
                }
            }
        }
    }
}

struct SubRow: View {
    @EnvironmentObject var store: Store
    let s: Record
    var body: some View {
        let st = Logic.subStatus(s), nx = Logic.subNext(s)
        let n = nx.isEmpty ? nil : Dates.diff(nx, Dates.today())
        Row(kind: .subs, record: s, title: s["name"].isEmpty ? "Unnamed" : s["name"], subtitle: [s["plan"], s["category"]].filter { !$0.isEmpty }, project: s["project"],
            whenMain: nx.isEmpty ? "" : Dates.short(nx),
            whenSub: nx.isEmpty ? (st == .cancelled ? "No more charges" : st == .paused ? "Paused" : "No date set") : Dates.rel(nx),
            whenColor: n != nil && n! <= 3 ? .orange : .primary) {
            SiteIcon(site: Favicons.site(forSub: s), name: s["name"])
        } meta: {
            HStack(spacing: 12) {
                Text(store.money(s.num("amount")) + (cycles[s["cycle"]] ?? "/mo")).monospacedDigit()
                if st != .active { Pill(label: st.label, color: st.color) }
            }
            .font(.callout)
        }
    }
}

// MARK: Revenue

struct RevenueView: View {
    @EnvironmentObject var store: Store
    @AppStorage("f.range") private var range = 30
    @AppStorage("f.src") private var src = "all"

    var body: some View {
        let t0 = Dates.today()
        let all = store.list(.revenue)
        let srcs = Array(Set(all.map { $0["source"].isEmpty ? "Other" : $0["source"] })).sorted()
        let base = all.filter { src == "all" || ($0["source"].isEmpty ? "Other" : $0["source"]) == src }
        let first = base.map { $0["date"] }.filter(Dates.isDate).min() ?? t0
        let life = range == 0
        let days = life ? Dates.diff(t0, first) + 1 : range
        let from = Dates.add(t0, days: -(days - 1))
        let inRange = base.filter { $0["date"] >= from && $0["date"] <= t0 }
        let prevFrom = Dates.add(from, days: -days)
        let tot = Logic.r2(inRange.map { $0.num("amount") }.reduce(0, +))
        let prev = Logic.r2(base.filter { $0["date"] >= prevFrom && $0["date"] < from }.map { $0.num("amount") }.reduce(0, +))
        let byDay: [String: Double] = { var m: [String: Double] = [:]; for e in inRange { m[e["date"], default: 0] += e.num("amount") }; return m }()
        let best = byDay.max { $0.value < $1.value }
        let refunds = inRange.filter { $0.num("amount") < 0 }
        let monthly = days > 90
        let points: [Point] = monthly
            ? monthlyPoints(Dictionary(grouping: inRange) { String($0["date"].prefix(7)) }.mapValues { $0.map { $0.num("amount") }.reduce(0, +) }, from: String(from.prefix(7)), to: String(t0.prefix(7)))
            : dailyPoints(inRange, dateField: "date", days: days)
        let span = life ? "lifetime" : "\(days) days"
        let shown = inRange.filter { hit(store.query, [$0["project"], $0["source"], $0["note"], $0["customer"], $0["amount"]]) }
        let groups = Dictionary(grouping: shown) { $0["date"] }

        VStack(alignment: .leading, spacing: 16) {
            HStack {
                FilterBar(value: $range, options: [(7, "7 days"), (30, "30 days"), (90, "90 days"), (365, "365 days"), (0, "Lifetime")])
                Spacer()
                if srcs.count > 1 {
                    Picker("Source", selection: $src) {
                        Text("Any source").tag("all")
                        ForEach(srcs, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden().fixedSize()
                }
            }
            StatRow(stats: [
                Stat(label: "Net · \(span)", value: store.money(tot), foot: life ? "Since \(Dates.short(first))" : change(tot, prev), footColor: life || prev == 0 ? .secondary : (tot >= prev ? .green : .red)),
                Stat(label: "Daily average", value: store.money(Logic.r2(tot / Double(max(days, 1)))), foot: "\(byDay.filter { $0.value != 0 }.count) of \(days) days had revenue"),
                Stat(label: "Best day", value: best.map { store.money($0.value) } ?? "—", foot: best.map { Dates.day($0.key) } ?? "No sales yet"),
                Stat(label: "Refunds", value: store.money(refunds.map { $0.num("amount") }.reduce(0, +)), foot: "\(refunds.count) in this range", valueColor: refunds.isEmpty ? .primary : .red),
            ])
            BarChart(title: "\(monthly ? "Monthly" : "Daily") revenue · \(span)", total: store.money(tot), points: points, unit: monthly ? .month : .day)
            Panel {
                if groups.isEmpty {
                    EmptyState(icon: "chart.bar", title: all.isEmpty ? "No revenue logged yet" : "No revenue in this range", text: all.isEmpty ? "Use Add Revenue to log a sale. Dodo Payments sales arrive on their own." : "Pick a longer range or change the search.")
                }
                LazyVStack(spacing: 0) {
                    ForEach(groups.keys.sorted(by: >), id: \.self) { d in
                        let list = groups[d]!.sorted { $0.num("amount") > $1.num("amount") }
                        let sum = Logic.r2(list.map { $0.num("amount") }.reduce(0, +))
                        HStack {
                            Text(Dates.day(d)).font(.callout.weight(.medium))
                            if d == t0 { Text("Today").font(.caption).foregroundStyle(.secondary) }
                            Spacer()
                            Text("\(list.count) \(list.count == 1 ? "entry" : "entries")").font(.caption).foregroundStyle(.secondary)
                            Text(store.money(sum)).font(.callout.weight(.semibold)).monospacedDigit().foregroundStyle(sum < 0 ? .red : .primary).frame(minWidth: 80, alignment: .trailing)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.primary.opacity(0.03))
                        ForEach(list) { e in Divider(); RevenueRow(e: e) }
                        Divider()
                    }
                }
            }
        }
    }

    private func change(_ cur: Double, _ prev: Double) -> String {
        guard prev != 0 else { return "No earlier data to compare" }
        let p = Int(((cur - prev) / abs(prev) * 100).rounded())
        return "\(p >= 0 ? "+" : "−")\(abs(p))% vs previous \(range) days"
    }
}

struct RevenueRow: View {
    @EnvironmentObject var store: Store
    let e: Record
    var body: some View {
        let a = e.num("amount")
        let paid = e["paidCurrency"].isEmpty || e["paidCurrency"] == store.currency ? "" : "\(e["paidCurrency"]) \(e["paidAmount"])"
        // Dodo notes start with the product name, which is already the title.
        let note = e["note"].hasPrefix(e["project"] + " · ") ? String(e["note"].dropFirst(e["project"].count + 3)) : e["note"]
        Row(kind: .revenue, record: e, title: e["project"].isEmpty ? "Unassigned" : e["project"], subtitle: [note, e["customer"]].filter { !$0.isEmpty },
            whenMain: store.money(a, sign: true), whenColor: a < 0 ? .red : .primary) {
            SiteIcon(site: store.projectSite(e["project"]), name: e["project"].isEmpty ? "?" : e["project"])
        } meta: {
            HStack(spacing: 10) {
                if !paid.isEmpty { Text(paid).foregroundStyle(.tertiary) }
                Label(e["source"].isEmpty ? "Other" : e["source"], systemImage: "wallet.pass").foregroundStyle(.secondary)
            }
            .font(.caption)
        }
    }
}

// MARK: Spending

struct SpendView: View {
    @EnvironmentObject var store: Store
    @AppStorage("f.months") private var months = 12

    var body: some View {
        let cur = String(Dates.today().prefix(7))
        let all = store.list(.spend)
        let firstM = all.map { $0["month"] }.filter { $0.count == 7 }.min() ?? cur
        let n: Int = {
            guard months == 0 else { return months }
            let y = (Int(cur.prefix(4)) ?? 0) - (Int(firstM.prefix(4)) ?? 0), m = (Int(cur.suffix(2)) ?? 0) - (Int(firstM.suffix(2)) ?? 0)
            return max(1, y * 12 + m + 1)
        }()
        let fromM = String(Dates.add(cur + "-01", months: -(n - 1)).prefix(7))
        let byM = Dictionary(grouping: all) { $0["month"] }.mapValues { Logic.r2($0.map { $0.num("amount") }.reduce(0, +)) }
        let revM = Dictionary(grouping: store.list(.revenue)) { String($0["date"].prefix(7)) }.mapValues { Logic.r2($0.map { $0.num("amount") }.reduce(0, +)) }
        let points = monthlyPoints(byM, from: fromM, to: cur)
        let logged = points.filter { $0.value != 0 }
        let tot = Logic.r2(points.map(\.value).reduce(0, +))
        let last = String(Dates.add(cur + "-01", months: -1).prefix(7))
        let profit = Logic.r2((revM[cur] ?? 0) - (byM[cur] ?? 0))
        let shown = all.filter { hit(store.query, [$0["category"], $0["project"], $0["note"], $0["amount"]]) }
        let groups = Dictionary(grouping: shown) { $0["month"] }

        VStack(alignment: .leading, spacing: 16) {
            FilterBar(value: $months, options: [(6, "6 months"), (12, "12 months"), (24, "2 years"), (0, "Lifetime")])
            StatRow(stats: [
                Stat(label: "This month", value: store.money(byM[cur] ?? 0), foot: Dates.month(cur)),
                Stat(label: "Last month", value: store.money(byM[last] ?? 0), foot: Dates.month(last)),
                Stat(label: "Monthly average", value: store.money(logged.isEmpty ? 0 : Logic.r2(tot / Double(logged.count))), foot: "\(logged.count) of \(n) months logged"),
                Stat(label: "Profit this month", value: store.money(profit), foot: "Revenue minus spending", valueColor: profit < 0 ? .red : .primary),
            ])
            BarChart(title: "Spending · \(months == 0 ? "lifetime" : "\(n) months")", total: store.money(tot), points: points, unit: .month, tint: .orange)
            Panel {
                if groups.isEmpty {
                    EmptyState(icon: "wallet.bifold", title: all.isEmpty ? "No spending logged yet" : "No entries match", text: all.isEmpty ? "Add what you spent each month: one total, or split it by category like Rent, Food, Tools." : "Try a category or note.")
                }
                ForEach(groups.keys.sorted(by: >), id: \.self) { m in
                    let list = groups[m]!.sorted { $0.num("amount") > $1.num("amount") }
                    HStack {
                        Text(Dates.month(m)).font(.callout.weight(.medium))
                        if m == cur { Text("This month").font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        if let r = revM[m] { Text("Revenue \(store.money(r))").font(.caption).foregroundStyle(.secondary) }
                        Text(store.money(byM[m] ?? 0)).font(.callout.weight(.semibold)).monospacedDigit().frame(minWidth: 80, alignment: .trailing)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Color.primary.opacity(0.03))
                    ForEach(list) { e in
                        Divider()
                        Row(kind: .spend, record: e, title: e["category"].isEmpty ? "Spending" : e["category"], subtitle: e["note"].isEmpty ? [] : [e["note"]], project: e["project"],
                            whenMain: store.money(e.num("amount"))) {
                            Avatar(text: e["category"].isEmpty ? "Spending" : e["category"])
                        } meta: { EmptyView() }
                    }
                    Divider()
                }
            }
        }
    }
}

// MARK: Ideas

enum IdeaType: String, CaseIterable {
    case weekend, app, article, video
    var label: String { ["weekend": "Weekend plan", "app": "App to try", "article": "Article idea", "video": "Video idea"][rawValue]! }
    var plural: String { ["weekend": "Weekend plans", "app": "Apps to try", "article": "Article ideas", "video": "Video ideas"][rawValue]! }
    var icon: String { ["weekend": "sun.max", "app": "app.badge", "article": "doc.text", "video": "play.rectangle"][rawValue]! }
    var color: Color { switch self { case .weekend: .orange; case .app: .blue; case .article: .purple; case .video: .pink } }
}

enum IdeaStatus: String, CaseIterable {
    case idea, planned, done
    var label: String { rawValue.capitalized }
    var color: Color { switch self { case .idea: .secondary; case .planned: .blue; case .done: .green } }
}

struct IdeasView: View {
    @EnvironmentObject var store: Store
    @AppStorage("f.itype") private var type = "all"
    @AppStorage("f.istat") private var stat = "open"
    @State private var text = ""
    @State private var addType = IdeaType.article

    var body: some View {
        let all = store.list(.ideas)
        let shown = all
            .filter { type == "all" || $0["type"] == type }
            .filter { stat == "all" || (stat == "done" ? $0["status"] == "done" : $0["status"] != "done") }
            .filter { hit(store.query, [$0["title"], $0["notes"], $0["link"], $0["project"]]) }
        let count = { (t: IdeaType) in all.filter { $0["type"] == t.rawValue && $0["status"] != "done" }.count }

        VStack(alignment: .leading, spacing: 16) {
            HStack {
                FilterBar(value: $type, options: [("all", "All")] + IdeaType.allCases.map { ($0.rawValue, count($0) > 0 ? "\($0.plural) \(count($0))" : $0.plural) })
                Spacer()
                FilterBar(value: $stat, options: [("open", "Open"), ("done", "Done"), ("all", "All")])
            }
            HStack(spacing: 10) {
                Image(systemName: "plus").foregroundStyle(.secondary)
                TextField("Add \(addType.label.lowercased())…", text: $text)
                    .textFieldStyle(.plain)
                    .onSubmit(add)
                Picker("", selection: $addType) {
                    ForEach(IdeaType.allCases, id: \.self) { Label($0.label, systemImage: $0.icon).tag($0) }
                }
                .labelsHidden().fixedSize()
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .card()
            .onChange(of: type) { _, t in if let it = IdeaType(rawValue: t) { addType = it } }
            .onAppear { if let it = IdeaType(rawValue: type) { addType = it } }
            Panel {
                if shown.isEmpty {
                    EmptyState(icon: "lightbulb", title: all.isEmpty ? "No ideas yet" : "Nothing here", text: all.isEmpty ? "Jot down weekend plans, apps you want to try, and article or video ideas. Type above and press Return." : "Switch the filter above.")
                }
                ForEach(IdeaType.allCases, id: \.self) { t in
                    let items = shown.filter { ($0["type"].isEmpty ? "article" : $0["type"]) == t.rawValue }.sorted(by: ideaSort)
                    if !items.isEmpty {
                        GroupHeader(title: t.plural, right: "\(items.count)")
                        ForEach(items) { i in Divider(); IdeaRow(i: i) }
                    }
                }
            }
        }
    }

    private func ideaSort(_ a: Record, _ b: Record) -> Bool {
        let order = ["planned": 0, "idea": 1, "done": 2]
        let oa = order[a["status"]] ?? 1, ob = order[b["status"]] ?? 1
        if oa != ob { return oa < ob }
        let da = a["date"].isEmpty ? "9999" : a["date"], db = b["date"].isEmpty ? "9999" : b["date"]
        if da != db { return da < db }
        return a["created"] > b["created"]
    }

    private func add() {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        var f: [String: JSON] = ["title": .str(t), "type": .str(addType.rawValue), "status": .str(addType == .weekend ? "planned" : "idea"), "date": .str(""), "link": .str(""), "notes": .str(""), "project": .str("")]
        if addType == .weekend { f["date"] = .str(nextSaturday()) }
        f["created"] = .str(ISO8601DateFormatter().string(from: Date()))
        store.put(.ideas, Record(id: Store.newId(), f: f))
        text = ""
    }

    private func nextSaturday() -> String {
        let wd = Dates.cal.component(.weekday, from: Date()) // 7 = Saturday
        return Dates.add(Dates.today(), days: (7 - wd + 7) % 7)
    }
}

struct IdeaRow: View {
    @EnvironmentObject var store: Store
    let i: Record
    var body: some View {
        let t = IdeaType(rawValue: i["type"]) ?? .article
        let st = IdeaStatus(rawValue: i["status"]) ?? .idea
        let host = URL(string: i["link"])?.host ?? ""
        let note = i["notes"].split(separator: "\n").first.map(String.init) ?? ""
        Row(kind: .ideas, record: i, title: i["title"], subtitle: [host, note].filter { !$0.isEmpty }, project: i["project"],
            whenMain: Dates.isDate(i["date"]) ? Dates.short(i["date"]) : "", whenSub: Dates.isDate(i["date"]) ? Dates.rel(i["date"]) : "", dim: st == .done) {
            Button {
                var r = i
                r["status"] = st == .done ? "idea" : "done"
                store.put(.ideas, r)
            } label: {
                Image(systemName: st == .done ? "checkmark.circle.fill" : t.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(st == .done ? Color.green : t.color)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill((st == .done ? Color.green : t.color).opacity(0.13)))
            }
            .buttonStyle(.plain)
            .help(st == .done ? "Mark as not done" : "Mark as done")
        } meta: {
            HStack(spacing: 10) {
                if !i["link"].isEmpty, let u = URL(string: i["link"]) {
                    Button { NSWorkspace.shared.open(u) } label: { Image(systemName: "arrow.up.right.square") }
                        .buttonStyle(.plain).foregroundStyle(.secondary).help("Open link")
                }
                if st == .planned { Pill(label: st.label, color: st.color) }
            }
        }
    }
}
