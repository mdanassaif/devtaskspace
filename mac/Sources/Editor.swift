// Add / edit sheet for every kind of record.
import SwiftUI

struct Step: Identifiable { let id = UUID(); var t: String; var d: Bool }

struct Editor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let target: EditTarget
    @State private var r: Record
    @State private var tags: String
    @State private var steps: [Step]
    @State private var newStep = ""
    @State private var refund: Bool
    @State private var error = ""
    @State private var confirmDelete = false
    @State private var file: URL?

    init(target: EditTarget) {
        self.target = target
        var rec = target.record ?? target.draft ?? Editor.blank(target.kind)
        if target.kind == .docs, let u = target.file, rec["title"].isEmpty { rec["title"] = u.deletingPathExtension().lastPathComponent }
        _file = State(initialValue: target.file)
        _r = State(initialValue: rec)
        _tags = State(initialValue: rec.tags.joined(separator: ", "))
        _steps = State(initialValue: rec.subtasks.map { Step(t: $0.t, d: $0.d) })
        _refund = State(initialValue: rec.num("amount") < 0)
        if target.kind == .revenue, rec.num("amount") < 0 {
            var abs = rec; abs["amount"] = String(-rec.num("amount")); _r = State(initialValue: abs)
        }
    }

    private var isNew: Bool { target.record == nil }
    private var kind: Kind { target.kind }

    static func blank(_ k: Kind) -> Record {
        let t0 = Dates.today()
        let f: [String: JSON]
        switch k {
        case .tasks: f = ["title": .str(""), "notes": .str(""), "project": .str(""), "due": .str(""), "pri": .str("normal"), "repeat": .str("none"), "tags": .arr([]), "subtasks": .arr([]), "done": .bool(false), "doneAt": .str("")]
        case .domains: f = ["name": .str(""), "project": .str(""), "registrar": .str(""), "dns": .str(""), "expires": .str(Dates.add(t0, months: 12)), "cost": .str(""), "autoRenew": .bool(true), "parked": .bool(false), "notes": .str("")]
        case .subs: f = ["name": .str(""), "plan": .str(""), "project": .str(""), "category": .str(""), "amount": .str(""), "cycle": .str("monthly"), "renews": .str(t0), "status": .str("active"), "notes": .str("")]
        case .revenue: f = ["amount": .str(""), "date": .str(t0), "project": .str(""), "source": .str(""), "customer": .str(""), "note": .str("")]
        case .spend: f = ["month": .str(String(t0.prefix(7))), "amount": .str(""), "category": .str(""), "project": .str(""), "note": .str("")]
        case .ideas: f = ["title": .str(""), "type": .str("article"), "status": .str("idea"), "date": .str(""), "link": .str(""), "notes": .str(""), "project": .str("")]
        case .docs: f = ["title": .str(""), "category": .str("Other"), "expires": .str(""), "notes": .str(""), "file": .str(""), "originalName": .str("")]
        case .goals: f = ["title": .str(""), "type": .str("goal"), "status": .str("active"), "target": .str(""), "current": .num(0), "unit": .str(""), "due": .str(""), "checks": .arr([]), "since": .str(t0), "why": .str(""), "notes": .str("")]
        case .notes: f = ["title": .str(""), "body": .str(""), "type": .str("note"), "date": .str(t0), "pinned": .bool(false), "tags": .arr([])]
        }
        return Record(id: Store.newId(), f: f)
    }

    private func s(_ k: String) -> Binding<String> { Binding(get: { r[k] }, set: { r[k] = $0; error = "" }) }
    private func b(_ k: String) -> Binding<Bool> { Binding(get: { r.flag(k) }, set: { r.set(k, .bool($0)) }) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isNew ? "New \(kind.noun.lowercased())" : title).font(.headline)
                Spacer()
                if r.flag("example") { Text("Example").font(.caption).foregroundStyle(.secondary) }
            }
            .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 4)
            Form { fields }
                .formStyle(.grouped)
            if !error.isEmpty {
                Text(error).font(.callout).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20)
            }
            HStack {
                if !isNew {
                    Button("Delete", role: .destructive) { confirmDelete = true }
                        .confirmationDialog("Delete this \(kind.noun.lowercased())?", isPresented: $confirmDelete) {
                            Button("Delete", role: .destructive) { store.delete(kind, r.id); store.show("Deleted"); dismiss() }
                        } message: { Text("It stays in the change history, so it can be restored.") }
                }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(isNew ? "Add" : "Save") { save() }.keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: kind == .notes ? 640 : 540)
    }

    private var title: String {
        switch kind {
        case .revenue: return "\(store.money(r.num("amount") * (refund ? -1 : 1), sign: true)) · \(Dates.short(r["date"]))"
        case .spend: return "\(store.money(r.num("amount"))) · \(Dates.month(r["month"]))"
        default: return r["title"].isEmpty ? (r["name"].isEmpty ? "Edit" : r["name"]) : r["title"]
        }
    }

    @ViewBuilder private var fields: some View {
        switch kind {
        case .tasks:
            TextField("Title", text: s("title"))
            DateField(label: "Due date", value: s("due"))
            SuggestField(label: "Project", text: s("project"), options: store.projects)
            Picker("Priority", selection: s("pri")) { ForEach(Pri.allCases, id: \.self) { Text($0.label).tag($0.rawValue) } }.pickerStyle(.segmented)
            Picker("Repeats", selection: s("repeat")) {
                Text("Does not repeat").tag("none")
                ForEach(["daily", "weekly", "monthly", "yearly"], id: \.self) { Text($0.capitalized).tag($0) }
            }
            TextField("Tags", text: $tags, prompt: Text("seo, design"))
            SwiftUI.Section("Steps") {
                ForEach($steps) { $st in
                    HStack {
                        Toggle("", isOn: $st.d).labelsHidden().toggleStyle(.checkbox)
                        TextField("", text: $st.t).textFieldStyle(.plain).strikethrough(st.d)
                        Button { steps.removeAll { $0.id == st.id } } label: { Image(systemName: "xmark") }.buttonStyle(.plain).foregroundStyle(.secondary)
                    }
                }
                TextField("Add a step", text: $newStep).onSubmit {
                    let t = newStep.trimmingCharacters(in: .whitespaces)
                    if !t.isEmpty { steps.append(Step(t: t, d: false)) }
                    newStep = ""
                }
            }
            SwiftUI.Section {
                TextField("Notes", text: s("notes"), prompt: Text("Links, context, anything"), axis: .vertical).lineLimit(3...8)
                Toggle("Completed", isOn: b("done"))
            }
        case .domains:
            TextField("Domain", text: s("name"), prompt: Text("example.com"))
            SuggestField(label: "Project", text: s("project"), options: store.projects)
            DateField(label: "Expires on", value: s("expires"))
            SuggestField(label: "Registrar", text: s("registrar"), options: store.values(.domains, "registrar", base: ["Cloudflare", "Namecheap", "Porkbun", "GoDaddy", "Spaceship"]))
            SuggestField(label: "DNS host", text: s("dns"), options: store.values(.domains, "dns", base: ["Cloudflare", "Vercel", "Netlify", "Registrar"]))
            TextField("Renewal price (\(store.currency)/yr)", text: s("cost"), prompt: Text("0.00"))
            Toggle("Auto-renew is on at the registrar", isOn: b("autoRenew"))
            Toggle("Parked (not in use)", isOn: b("parked"))
            TextField("Notes", text: s("notes"), prompt: Text("Login email, transfer lock, plans"), axis: .vertical).lineLimit(2...6)
        case .subs:
            TextField("Service", text: s("name"), prompt: Text("Vercel"))
            TextField("Website", text: s("website"), prompt: Text(Favicons.site(forSub: r).isEmpty ? "vercel.com (for the logo)" : Favicons.site(forSub: r)))
            TextField("Plan", text: s("plan"), prompt: Text("Pro"))
            SuggestField(label: "Category", text: s("category"), options: store.values(.subs, "category", base: ["Hosting", "AI", "Email", "Design", "Dev tools", "Analytics", "Bills", "Streaming"]))
            TextField("Price (\(store.currency))", text: s("amount"), prompt: Text("0.00"))
            Picker("Billed", selection: s("cycle")) { ForEach(cycleOrder, id: \.self) { Text($0.capitalized).tag($0) } }
            DateField(label: "Next billing date", value: s("renews"))
            SuggestField(label: "Used for", text: s("project"), options: store.projects)
            Picker("Status", selection: s("status")) { ForEach(SubStatus.allCases, id: \.self) { Text($0.label).tag($0.rawValue) } }.pickerStyle(.segmented)
            TextField("Notes", text: s("notes"), prompt: Text("Card used, cancel link, seats"), axis: .vertical).lineLimit(2...6)
        case .revenue:
            Picker("Type", selection: $refund) { Text("Sale").tag(false); Text("Refund").tag(true) }.pickerStyle(.segmented)
            TextField("Amount (\(store.currency))", text: s("amount"), prompt: Text("0.00"))
            DateField(label: "Date", value: s("date"), optional: false)
            SuggestField(label: "Product", text: s("project"), options: store.projects)
            SuggestField(label: "Source", text: s("source"), options: store.values(.revenue, "source", base: ["Dodo Payments", "Stripe", "Lemon Squeezy", "Gumroad", "AdSense", "Sponsor", "Client", "Other"]))
            TextField("Customer", text: s("customer"), prompt: Text("Name or email (optional)"))
            TextField("Note", text: s("note"), prompt: Text("Lifetime license, sponsorship, …"))
        case .spend:
            TextField("Amount (\(store.currency))", text: s("amount"), prompt: Text("0.00"))
            MonthField(value: s("month"))
            SuggestField(label: "Category", text: s("category"), options: store.values(.spend, "category", base: ["Total", "Rent", "Food", "Bills", "Tools", "Travel", "Shopping", "Family", "Other"]))
            SuggestField(label: "Project", text: s("project"), options: store.projects)
            TextField("Note", text: s("note"), prompt: Text("What it was for (optional)"))
        case .ideas:
            TextField("Title", text: s("title"))
            Picker("Type", selection: s("type")) { ForEach(IdeaType.allCases, id: \.self) { Label($0.label, systemImage: $0.icon).tag($0.rawValue) } }
            Picker("Status", selection: s("status")) { ForEach(IdeaStatus.allCases, id: \.self) { Text($0.label).tag($0.rawValue) } }.pickerStyle(.segmented)
            DateField(label: r["type"] == "weekend" ? "Weekend of" : "Date", value: s("date"))
            TextField("Link", text: s("link"), prompt: Text("https://…"))
            SuggestField(label: "Project", text: s("project"), options: store.projects)
            TextField("Notes", text: s("notes"), prompt: Text("Outline, why it matters, anything"), axis: .vertical).lineLimit(3...10)
        case .docs:
            LabeledContent("File") {
                HStack {
                    Text(file?.lastPathComponent ?? (r["originalName"].isEmpty ? "No file yet" : r["originalName"])).lineLimit(1).truncationMode(.middle).foregroundStyle(.secondary)
                    Button(file == nil && r["file"].isEmpty ? "Choose…" : "Replace…") {
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK, let u = panel.url {
                            file = u
                            if r["title"].isEmpty { r["title"] = u.deletingPathExtension().lastPathComponent }
                        }
                    }
                }
            }
            TextField("Title", text: s("title"), prompt: Text("Passport, PAN card, Rent agreement…"))
            Picker("Category", selection: s("category")) { ForEach(docCategories, id: \.self) { Text($0).tag($0) } }
            DateField(label: "Expires on", value: s("expires"))
            TextField("Notes", text: s("notes"), prompt: Text("Number, where the original is, renewal steps"), axis: .vertical).lineLimit(2...6)
        case .goals:
            Picker("Type", selection: s("type")) { ForEach(GoalType.allCases, id: \.self) { Label($0.label, systemImage: $0.icon).tag($0.rawValue) } }
            TextField("Title", text: s("title"), prompt: Text(r["type"] == "promise" ? "No phone before 10am" : r["type"] == "habit" ? "Walk 30 minutes" : "Reach $5K MRR"))
            TextField("Why it matters", text: s("why"), prompt: Text("Optional, but it helps on hard days"))
            if r["type"] == "goal" || r["type"].isEmpty {
                TextField("Target", text: s("target"), prompt: Text("5000"))
                TextField("Current", text: s("current"), prompt: Text("0"))
                TextField("Unit", text: s("unit"), prompt: Text("$ MRR, articles, kg…"))
                DateField(label: "By", value: s("due"))
            } else {
                DateField(label: "Started", value: s("since"), optional: false)
            }
            Picker("Status", selection: s("status")) { Text("Active").tag("active"); Text("Achieved").tag("done"); Text("Dropped").tag("dropped") }.pickerStyle(.segmented)
            TextField("Notes", text: s("notes"), axis: .vertical).lineLimit(2...6)
        case .notes:
            TextField("Title", text: s("title"))
            Picker("Type", selection: s("type")) { Text("Note").tag("note"); Text("Journal").tag("journal") }.pickerStyle(.segmented)
            if r["type"] == "journal" { DateField(label: "Day", value: s("date"), optional: false) }
            Toggle("Pin to top", isOn: b("pinned"))
            TextField("Tags", text: $tags, prompt: Text("work, health"))
            SwiftUI.Section("Text") {
                TextEditor(text: s("body")).font(.body).frame(minHeight: 260).scrollContentBackground(.hidden)
            }
        }
    }

    private func number(_ k: String) -> Double? {
        let t = r[k].replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? nil : Double(t)
    }

    private func save() {
        var rec = r
        let trim = { (k: String) in rec[k] = rec[k].trimmingCharacters(in: .whitespacesAndNewlines) }
        for k in ["title", "name", "notes", "note", "project", "registrar", "dns", "plan", "category", "source", "customer", "link"] where rec.f[k] != nil { trim(k) }
        switch kind {
        case .tasks:
            guard !rec["title"].isEmpty else { error = "Add a title to save this task."; return }
            rec.set("tags", .arr(tags.split(separator: ",").map { .str($0.trimmingCharacters(in: .whitespaces)) }.filter { $0 != .str("") }))
            rec.set("subtasks", .arr(steps.filter { !$0.t.trimmingCharacters(in: .whitespaces).isEmpty }.map { .obj(["t": .str($0.t), "d": .bool($0.d)]) }))
            let wasDone = target.record?.flag("done") ?? false
            if rec.flag("done") && !wasDone { rec["doneAt"] = ISO8601DateFormatter().string(from: Date()) }
            if !rec.flag("done") { rec["doneAt"] = "" }
        case .domains:
            let name = rec["name"].lowercased()
                .replacingOccurrences(of: #"^https?://"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"^www\."#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"[/?#].*$"#, with: "", options: .regularExpression)
            guard name.contains(".") else { error = "Enter a domain like example.com."; return }
            rec["name"] = name
            if let c = number("cost") { rec.set("cost", .num(Logic.r2(c))) } else { rec["cost"] = "" }
        case .subs:
            guard !rec["name"].isEmpty else { error = "Add the service name."; return }
            guard let a = number("amount"), a >= 0 else { error = "Enter the price, like 20 or 99."; return }
            rec.set("amount", .num(Logic.r2(a)))
        case .revenue:
            guard let a = number("amount"), a != 0 else { error = "Enter an amount above zero."; return }
            rec.set("amount", .num(Logic.r2(abs(a) * (refund ? -1 : 1))))
            if rec["source"].isEmpty { rec["source"] = "Other" }
        case .spend:
            guard let a = number("amount"), a > 0 else { error = "Enter what you spent, like 850."; return }
            rec.set("amount", .num(Logic.r2(a)))
            if rec["category"].isEmpty { rec["category"] = "Total" }
        case .ideas:
            guard !rec["title"].isEmpty else { error = "Give the idea a title."; return }
        case .docs:
            guard file != nil || !rec["file"].isEmpty else { error = "Choose the file to keep."; return }
            if let u = file {
                guard let stored = store.storeFile(u, id: rec.id) else { error = "Couldn't copy the file. Is the Anas HQ server running?"; return }
                rec["file"] = stored
                rec["originalName"] = u.lastPathComponent
            }
            if rec["title"].isEmpty { rec["title"] = rec["originalName"] }
        case .goals:
            guard !rec["title"].isEmpty else { error = "Give it a title."; return }
            if rec["type"] == "goal" {
                if let t = number("target") { rec.set("target", .num(t)) } else { rec["target"] = "" }
                rec.set("current", .num(number("current") ?? 0))
                if let t = number("target"), t > 0, (number("current") ?? 0) >= t, rec["status"] == "active" { rec["status"] = "done" }
            }
        case .notes:
            guard !rec["title"].isEmpty || !rec["body"].isEmpty else { error = "Write something first."; return }
            rec.set("tags", .arr(tags.split(separator: ",").map { .str($0.trimmingCharacters(in: .whitespaces)) }.filter { $0 != .str("") }))
            rec["updated"] = ISO8601DateFormatter().string(from: Date())
        }
        rec.f["example"] = nil
        if isNew { rec["created"] = ISO8601DateFormatter().string(from: Date()) }
        store.put(kind, rec)
        store.show(isNew ? "Added" : "Saved")
        dismiss()
    }
}

/// A date stored as "YYYY-MM-DD", or empty when not set.
struct DateField: View {
    let label: String
    @Binding var value: String
    var optional = true
    var body: some View {
        LabeledContent(label) {
            if Dates.isDate(value) {
                HStack(spacing: 6) {
                    DatePicker("", selection: Binding(get: { Dates.date(value) ?? Date() }, set: { value = Dates.ymd.string(from: $0) }), displayedComponents: .date)
                        .labelsHidden().datePickerStyle(.field)
                    if optional {
                        Button { value = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).foregroundStyle(.secondary).help("Clear date")
                    }
                }
            } else {
                Button("Set date") { value = Dates.today() }
            }
        }
    }
}

/// "YYYY-MM" as a month + year picker.
struct MonthField: View {
    @Binding var value: String
    var body: some View {
        let y = Int(value.prefix(4)) ?? Dates.cal.component(.year, from: Date())
        let m = Int(value.suffix(2)) ?? 1
        let thisYear = Dates.cal.component(.year, from: Date())
        LabeledContent("Month") {
            HStack {
                Picker("", selection: Binding(get: { m }, set: { value = String(format: "%04d-%02d", y, $0) })) {
                    ForEach(1...12, id: \.self) { Text(DateFormatter().monthSymbols[$0 - 1]).tag($0) }
                }
                .labelsHidden().fixedSize()
                Picker("", selection: Binding(get: { y }, set: { value = String(format: "%04d-%02d", $0, m) })) {
                    ForEach((thisYear - 6)...(thisYear + 1), id: \.self) { Text(String($0)).tag($0) }
                }
                .labelsHidden().fixedSize()
            }
        }
    }
}

/// Free text with a menu of earlier values.
struct SuggestField: View {
    let label: String
    @Binding var text: String
    let options: [String]
    var body: some View {
        HStack(spacing: 4) {
            TextField(label, text: $text, prompt: Text("None"))
            if !options.isEmpty {
                Menu {
                    ForEach(options, id: \.self) { o in Button(o) { text = o } }
                } label: { Image(systemName: "chevron.up.chevron.down") }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            }
        }
    }
}
