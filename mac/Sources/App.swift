// App entry: main window with sidebar, menu bar extra, keyboard shortcuts, login item.
import SwiftUI
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ n: Notification) {
        // First launch: start at login so the menu bar count is always there (toggle in the menu bar panel).
        if SMAppService.mainApp.status == .notRegistered && !UserDefaults.standard.bool(forKey: "loginAsked") {
            UserDefaults.standard.set(true, forKey: "loginAsked")
            try? SMAppService.mainApp.register()
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { false }
}

@main
struct AnasHQApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store = Store()

    var body: some Scene {
        Window("Anas HQ", id: "main") {
            RootView()
                .environmentObject(store)
                .frame(minWidth: 900, minHeight: 600)
        }
        .defaultSize(width: 1240, height: 840)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(store.section.newLabel) { store.editing = EditTarget(kind: store.section.kind) }
                    .keyboardShortcut("n")
            }
            CommandGroup(after: .sidebar) {
                Button("Reload") { Task { await store.load() } }.keyboardShortcut("r")
                Divider()
                ForEach(Array(Section.allCases.enumerated().prefix(9)), id: \.element) { i, s in
                    Button(s.label) { store.section = s }.keyboardShortcut(KeyEquivalent(Character(String(i + 1))))
                }
            }
        }

        MenuBarExtra {
            MenuBarPanel().environmentObject(store)
        } label: {
            let n = store.dueCount
            Image(systemName: "square.grid.2x2")
            if n > 0 { Text("\(n)") }
        }
        .menuBarExtraStyle(.window)
    }
}

struct RootView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        NavigationSplitView {
            List(selection: Binding(get: { store.section }, set: { if let s = $0 { store.section = s } })) {
                navItem(.today)
                SwiftUI.Section("Personal") {
                    ForEach([Section.tasks, .goals, .spin, .notes, .ideas, .docs]) { navItem($0) }
                }
                SwiftUI.Section("Business & money") {
                    ForEach([Section.revenue, .spend, .subs, .domains]) { navItem($0) }
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210)
            .safeAreaInset(edge: .bottom) { footer }
        } detail: {
            ScrollView {
                Group {
                    if !store.loaded {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 120)
                    } else if !store.online && store.list(.tasks).isEmpty && store.list(.revenue).isEmpty {
                        EmptyState(icon: "bolt.horizontal.circle", title: "Anas HQ server isn't running",
                                   text: "Run bash ~/Desktop/anas-hq/setup.sh once in Terminal. It then starts by itself at login.")
                            .padding(.top, 80)
                    } else {
                        switch store.section {
                        case .today: TodayView()
                        case .tasks: TasksView()
                        case .domains: DomainsView()
                        case .subs: SubsView()
                        case .revenue: RevenueView()
                        case .spend: SpendView()
                        case .ideas: IdeasView()
                        case .docs: DocsView()
                        case .goals: GoalsView()
                        case .notes: NotesView()
                        case .spin: SpinView()
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: 1180)
                .frame(maxWidth: .infinity)
            }
            // On Today the greeting banner is the header, so the window title stays empty.
            .navigationTitle(store.section == .today ? "" : store.section.label)
            .navigationSubtitle(store.section == .today ? "" : subtitle)
            .searchable(text: $store.query, placement: .toolbar, prompt: "Search \(store.section.label.lowercased())")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { store.editing = EditTarget(kind: store.section.kind) } label: { Label(store.section.newLabel, systemImage: "plus") }
                        .help("\(store.section.newLabel) (⌘N)")
                }
            }
        }
        .sheet(item: $store.editing) { t in Editor(target: t).environmentObject(store) }
        .overlay(alignment: .bottom) {
            if let msg = store.toast {
                Text(msg).font(.callout)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Capsule().fill(.regularMaterial).shadow(radius: 6))
                    .padding(.bottom, 22)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.18), value: store.toast)
        .onChange(of: store.section) { _, _ in store.query = "" }
        .task {
            // Debug: `AnasHQ --snapshot <out.png>` renders the current section to a PNG and quits.
            let args = CommandLine.arguments
            guard let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count else { return }
            try? await Task.sleep(nanoseconds: 9_000_000_000)
            let content = Group {
                switch store.section {
                case .today: TodayView()
                case .tasks: TasksView()
                case .domains: DomainsView()
                case .subs: SubsView()
                case .revenue: RevenueView()
                case .spend: SpendView()
                case .ideas: IdeasView()
                case .docs: DocsView()
                case .goals: GoalsView()
                case .notes: NotesView()
                        case .spin: SpinView()
                }
            }
            .environmentObject(store)
            .padding(24).frame(width: 1100)
            .background(Color(nsColor: .windowBackgroundColor))
            let r = ImageRenderer(content: content)
            r.scale = 1.5
            if let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
                try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: args[i + 1]))
            }
            NSApp.terminate(nil)
        }
    }

    private func navItem(_ s: Section) -> some View {
        Label(s.label, systemImage: s.icon).badge(badge(s)).tag(s)
    }

    private func badge(_ s: Section) -> Int {
        switch s {
        case .tasks: return store.openTasks.count
        case .domains: return store.list(.domains).filter { [.expiring, .expired].contains(Logic.domStatus($0)) }.count
        case .ideas: return store.list(.ideas).filter { $0["status"] == "planned" }.count
        case .goals: let t0 = Dates.today(); return store.list(.goals).filter { $0["type"] != "goal" && ($0["status"].isEmpty || $0["status"] == "active") && !$0.strings("checks").contains(t0) }.count
        case .docs: return store.list(.docs).filter { Dates.isDate($0["expires"]) && $0["expires"] <= Dates.add(Dates.today(), days: 90) }.count
        default: return 0
        }
    }

    private var subtitle: String {
        switch store.section {
        case .today: return Dates.day(Dates.today())
        case .tasks: let all = store.list(.tasks), open = all.filter { !$0.flag("done") }.count; return "\(open) open · \(all.count - open) done"
        case .domains: return "\(store.list(.domains).count) domains"
        case .subs: return "\(store.list(.subs).count) subscriptions"
        case .revenue: return "\(store.list(.revenue).count) entries"
        case .spend: return "\(Set(store.list(.spend).map { $0["month"] }).count) months logged"
        case .ideas: return "\(store.list(.ideas).filter { $0["status"] != "done" }.count) open"
        case .docs: return "\(store.list(.docs).count) documents"
        case .goals: return "\(store.list(.goals).filter { $0["status"].isEmpty || $0["status"] == "active" }.count) active"
        case .spin: return "Let the wheel pick your next habit"
        case .notes: return "\(store.list(.notes).filter { $0["type"] != "journal" }.count) notes · \(store.list(.notes).filter { $0["type"] == "journal" }.count) journal entries"
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Circle().fill(store.online ? Color.green : Color.red).frame(width: 6, height: 6)
            Text(store.online ? "Saved" : "Offline")
                .lineLimit(1)
                .help(store.online ? "Saved on this Mac, backed up daily" : "Run setup.sh to start the HQ server")
            Spacer(minLength: 8)
            Menu {
                ForEach(["USD", "EUR", "GBP", "INR"], id: \.self) { c in
                    Button { store.setCurrency(c) } label: {
                        if c == store.currency { Label(c, systemImage: "checkmark") } else { Text(c) }
                    }
                }
            } label: {
                Text(store.currency)
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .help("Currency for all amounts")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 18).padding(.vertical, 12)
    }
}

/// The panel that drops down from the menu bar icon.
struct MenuBarPanel: View {
    @EnvironmentObject var store: Store
    @ObservedObject private var weather = Weather.shared
    @Environment(\.openWindow) private var openWindow
    @State private var text = ""
    @State private var atLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        let t0 = Dates.today(), part = DayPart.now()
        let due = store.openTasks.filter { Dates.isDate($0["due"]) && $0["due"] <= t0 }.sorted(by: Logic.taskSort)
        let habits = store.list(.goals).filter { $0["type"] != "goal" && ($0["status"].isEmpty || $0["status"] == "active") && !$0.strings("checks").contains(t0) }
        let rev = store.list(.revenue)
        let revToday = rev.filter { $0["date"] == t0 }.map { $0.num("amount") }.reduce(0, +)
        let rev30 = rev.filter { $0["date"] > Dates.add(t0, days: -30) }.map { $0.num("amount") }.reduce(0, +)
        let (_, symbol) = weather.describe(night: part == .night)

        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .leading) {
                Scenery(part: part)
                VStack(alignment: .leading, spacing: 2) {
                    Text(part.greeting).font(.headline)
                    HStack(spacing: 5) {
                        Text(Dates.day(t0))
                        if !weather.tempText.isEmpty {
                            Text("·")
                            Image(systemName: symbol)
                            Text(weather.tempText)
                        }
                    }
                    .font(.caption).opacity(0.85)
                }
                .foregroundStyle(part.lightText ? Color.white : Color(red: 0.12, green: 0.14, blue: 0.22))
                .padding(.horizontal, 14)
            }
            .frame(height: 70)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "plus").foregroundStyle(.secondary)
                    TextField("Add a task for today", text: $text)
                        .textFieldStyle(.plain)
                        .onSubmit { store.quickAddTask(text, defaultToday: true); text = "" }
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.05)))

                if due.isEmpty && habits.isEmpty {
                    Text("Nothing due today").font(.callout).foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(due.prefix(6)) { t in
                            line(icon: "circle", color: Logic.pri(t) == .normal ? .secondary : Logic.pri(t).color, title: t["title"],
                                 trailing: Logic.bucket(t) == .overdue ? Dates.rel(t["due"]) : "", trailingColor: .red) { store.toggleTask(t) }
                        }
                        ForEach(habits.prefix(4)) { g in
                            let gt = GoalType(rawValue: g["type"]) ?? .habit
                            line(icon: gt.icon, color: gt.color, title: g["title"], trailing: Logic.streak(g.strings("checks")) > 0 ? "\(Logic.streak(g.strings("checks")))d" : "", trailingColor: .secondary) { store.toggleCheck(g) }
                        }
                    }
                }

                Text("Revenue today \(store.money(revToday)) · 30 days \(store.money(rev30))")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            .padding(14)

            Divider()
            HStack {
                Button("Open Anas HQ") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.plain).foregroundStyle(Color.accentColor)
                Spacer()
                Menu {
                    Toggle("Open at Login", isOn: $atLogin)
                    Divider()
                    Button("Quit Anas HQ") { NSApp.terminate(nil) }
                } label: { Image(systemName: "gearshape") }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            .padding(.horizontal, 14).padding(.vertical, 10)
        }
        .frame(width: 300)
        .task { await weather.refresh() }
        .onChange(of: atLogin) { _, on in
            if on { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() }
        }
    }

    private func line(icon: String, color: Color, title: String, trailing: String, trailingColor: Color, action: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Button(action: action) { Image(systemName: icon).foregroundStyle(color).frame(width: 16) }.buttonStyle(.plain)
            Text(title).lineLimit(1)
            Spacer(minLength: 6)
            if !trailing.isEmpty { Text(trailing).font(.caption).foregroundStyle(trailingColor) }
        }
        .font(.callout)
    }
}
