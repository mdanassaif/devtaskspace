// Spin: a wheel of habits, promises and simple to-do goals not yet worked on today. Spin it, do what it lands on, tick it off.
import SwiftUI

struct SpinView: View {
    @EnvironmentObject var store: Store
    /// Habits taken off the wheel, by id. Kept on this Mac only; the habit itself stays in Goals.
    @AppStorage("spin.off") private var offRaw = ""
    @State private var rotation: Double = 0
    @State private var spinning = false
    @State private var picked: String?
    @State private var text = ""
    @State private var deleting: Record?

    private var off: Set<String> { Set(offRaw.split(separator: ",").map(String.init)) }
    private var habits: [Record] {
        store.list(.goals)
            // Long-term goals with a number to reach (apps live, clicks) aren't one-sitting work; they stay in Goals.
            .filter { $0["type"] == "habit" || $0["type"] == "promise" || $0.num("target") <= 0 }
            .filter { $0["status"].isEmpty || $0["status"] == "active" }
            .sorted { $0["created"] < $1["created"] }
    }
    /// One-time to-dos (goals with no number) are finished for good; habits and promises come back each day.
    private func isTodo(_ r: Record) -> Bool { r["type"] != "habit" && r["type"] != "promise" }
    private var open: [Record] { let t0 = Dates.today(); return habits.filter { isTodo($0) || !$0.strings("checks").contains(t0) } }
    /// Habits ticked today, and to-dos finished today.
    private var done: [Record] {
        let t0 = Dates.today()
        return store.list(.goals).filter { r in
            isTodo(r) ? r["status"] == "done" && r["doneAt"] == t0 && r.num("target") <= 0
                      : (r["status"].isEmpty || r["status"] == "active") && r.strings("checks").contains(t0)
        }
    }
    private var wheel: [Record] { open.filter { !off.contains($0.id) } }

    var body: some View {
        let open = open, wheel = wheel
        let doneToday = done.count, total = open.count + doneToday

        VStack(alignment: .leading, spacing: 16) {
            StatRow(stats: [
                Stat(label: "On the wheel", value: "\(wheel.count)", foot: open.count > wheel.count ? "\(open.count - wheel.count) taken off" : "Everything open today"),
                Stat(label: "Done today", value: "\(doneToday)/\(total)", foot: total > 0 && open.isEmpty ? "Everything done today" : "Habits come back tomorrow, to-dos are finished", footColor: total > 0 && open.isEmpty ? .green : .secondary),
            ])

            HStack(alignment: .top, spacing: 24) {
                Wheel(items: wheel, rotation: rotation)
                    .frame(width: 380, height: 380)
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .card()

                VStack(alignment: .leading, spacing: 16) {
                    picker(open: open, wheel: wheel)
                    list(open: open)
                }
                .frame(width: 380)
            }
        }
        .animation(.easeOut(duration: 0.2), value: picked)
        .animation(.easeOut(duration: 0.2), value: wheel.map(\.id))
        .confirmationDialog("Delete “\(deleting?["title"] ?? "")”?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), presenting: deleting) { r in
            Button("Delete", role: .destructive) { store.delete(.goals, r.id); if picked == r.id { picked = nil } }
        } message: { _ in
            Text("It's removed from Goals too.")
        }
    }

    /// The spin button, or what the wheel picked and what to do next.
    @ViewBuilder private func picker(open: [Record], wheel: [Record]) -> some View {
        if let r = habits.first(where: { $0.id == picked }), !spinning {
            VStack(alignment: .leading, spacing: 12) {
                Text("DO THIS NOW").font(.caption.weight(.semibold)).tracking(0.6).foregroundStyle(.secondary)
                Text(r["title"]).font(.title2.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                if !r["why"].isEmpty { Text(r["why"]).font(.callout).foregroundStyle(.secondary) }
                HStack(spacing: 8) {
                    Button { finish(r) } label: { Label("I did it", systemImage: "checkmark") }
                        .buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.defaultAction)
                    Button("Spin again", action: spin).controlSize(.large)
                    Spacer()
                    Button { setOnWheel(r, false) } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.plain).foregroundStyle(.secondary).help("Take off the wheel")
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text(open.isEmpty ? (habits.isEmpty ? "Add something to work on below" : "Everything is done for today") : "Can't pick what to work on? Let the wheel decide.")
                    .font(.callout).foregroundStyle(.secondary)
                Button(action: spin) {
                    Label(spinning ? "Spinning…" : "Spin", systemImage: "arrow.clockwise").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(spinning || wheel.isEmpty)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }

    /// Every open item with a switch for the wheel, a field to add a new one, and what's done today.
    private func list(open: [Record]) -> some View {
        Panel {
            GroupHeader(title: "On your list", right: "\(open.count) open today")
            let slot = Dictionary(uniqueKeysWithValues: wheel.enumerated().map { ($1.id, $0) })
            ForEach(open) { r in
                Divider()
                let on = !off.contains(r.id)
                HStack(spacing: 10) {
                    // Same color as its slice on the wheel.
                    Circle().fill(slot[r.id].map(Wheel.color) ?? Color.primary.opacity(0.12)).frame(width: 10, height: 10)
                    Text(r["title"]).lineLimit(1).foregroundStyle(on ? .primary : .secondary)
                    Text(isTodo(r) ? "To-do" : GoalType(rawValue: r["type"])?.label ?? "").font(.caption).foregroundStyle(.tertiary).lineLimit(1)
                    Spacer()
                    Toggle("", isOn: Binding(get: { on }, set: { setOnWheel(r, $0) }))
                        .toggleStyle(.switch).controlSize(.mini).labelsHidden()
                        .help(on ? "Take off the wheel" : "Put on the wheel")
                        .disabled(spinning)
                }
                .padding(.horizontal, 16).padding(.vertical, 9)
                .contentShape(Rectangle())
                .contextMenu {
                    Button("Done") { finish(r) }
                    Button("Edit…") { store.editing = EditTarget(kind: .goals, record: r) }
                    Divider()
                    Button("Delete…", role: .destructive) { deleting = r }
                }
            }
            Divider()
            HStack(spacing: 10) {
                Image(systemName: "plus").foregroundStyle(.secondary)
                TextField("Add something to work on, e.g. “Read 10 pages”", text: $text)
                    .textFieldStyle(.plain)
                    .onSubmit(add)
            }
            .padding(.horizontal, 16).padding(.vertical, 11)
            let finished = done
            if !finished.isEmpty {
                Divider()
                GroupHeader(title: "Done today", right: "\(finished.count)")
                ForEach(finished) { r in
                    Divider()
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text(r["title"]).lineLimit(1).foregroundStyle(.secondary)
                        Spacer()
                        // Ticked by mistake, or didn't actually keep it: back onto the wheel.
                        Button("Undo") { undo(r) }
                            .controlSize(.small)
                            .help("Not done after all. Put it back on the wheel")
                    }
                    .padding(.horizontal, 16).padding(.vertical, 9)
                }
            }
        }
    }

    private func spin() {
        let slices = wheel
        guard !slices.isEmpty, !spinning else { return }
        let size = 360 / Double(slices.count)
        let index = Int.random(in: 0..<slices.count)
        // Somewhere inside the slice, away from its edges.
        let landing = (Double(index) + .random(in: 0.2...0.8)) * size
        // The pointer is at the top: turn a few full times, then until `landing` sits under it.
        let base = rotation + 360 * 5
        let target = base + (360 - (base + landing).truncatingRemainder(dividingBy: 360))
        picked = nil
        spinning = true
        withAnimation(.timingCurve(0.12, 0.8, 0.2, 1, duration: 3.4)) {
            rotation = target
        } completion: {
            spinning = false
            picked = slices[index].id
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
    }

    private func finish(_ r: Record) {
        if isTodo(r) {
            var d = r
            d["status"] = "done"
            d["doneAt"] = Dates.today()
            store.put(.goals, d)
        } else {
            store.toggleCheck(r)
        }
        store.show(isTodo(r) ? "Nice. “\(r["title"])” is done" : "Nice. “\(r["title"])” done for today")
        picked = nil
    }

    private func undo(_ r: Record) {
        guard isTodo(r) else { store.toggleCheck(r); return }
        var d = r
        d["status"] = "active"
        d["doneAt"] = ""
        store.put(.goals, d)
    }

    private func setOnWheel(_ r: Record, _ on: Bool) {
        var set = off
        if on { set.remove(r.id) } else { set.insert(r.id) }
        // Drop ids of deleted habits so the list doesn't grow forever.
        let ids = Set(habits.map(\.id))
        offRaw = set.filter(ids.contains).sorted().joined(separator: ",")
        if !on && picked == r.id { picked = nil }
    }

    private func add() {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        let f: [String: JSON] = [
            "title": .str(t), "type": .str("habit"), "status": .str("active"), "notes": .str(""), "why": .str(""),
            "checks": .arr([]), "since": .str(Dates.today()), "created": .str(ISO8601DateFormatter().string(from: Date())),
        ]
        store.put(.goals, Record(id: Store.newId(), f: f))
        text = ""
    }
}

/// The wheel: one slice per habit with its name, a pointer at the top.
private struct Wheel: View {
    let items: [Record]
    let rotation: Double

    static let colors: [Color] = [.teal, .indigo, .orange, .pink, .blue, .green, .purple, .brown]
    static func color(_ i: Int) -> Color { colors[i % colors.count] }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height), r = side / 2
            ZStack {
                if items.isEmpty {
                    Circle().fill(Color.primary.opacity(0.05))
                    Circle().strokeBorder(Color(nsColor: .separatorColor), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    Text("Nothing on the wheel").font(.callout).foregroundStyle(.secondary).offset(y: r * 0.45)
                } else {
                    let size = 360 / Double(items.count)
                    ZStack {
                        ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                            let start = Double(i) * size
                            Slice(start: .degrees(start - 90), end: .degrees(start + size - 90))
                                .fill(Self.color(i).opacity(0.85))
                            if items.count > 1 {
                                Slice(start: .degrees(start - 90), end: .degrees(start + size - 90))
                                    .stroke(Color(nsColor: .controlBackgroundColor), lineWidth: 2)
                            }
                            // Names on the right half read center-out, so none are upside down when the wheel stops.
                            let mid = (start + size / 2 + rotation).truncatingRemainder(dividingBy: 360)
                            label(item["title"], radius: r, count: items.count, flip: mid > 1 && mid < 179)
                                .rotationEffect(.degrees(start + size / 2))
                        }
                    }
                    .rotationEffect(.degrees(rotation))
                }
                Circle().fill(Color(nsColor: .controlBackgroundColor)).frame(width: side * 0.2, height: side * 0.2)
                    .overlay(Circle().strokeBorder(Color(nsColor: .separatorColor)))
                Image(systemName: "arrow.clockwise").font(.system(size: side * 0.05, weight: .semibold)).foregroundStyle(.secondary)
                Pointer().fill(Color.primary).frame(width: 22, height: 26).offset(y: -r + 4)
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// The name runs along the slice's center line, between the rim and the middle.
    private func label(_ title: String, radius r: CGFloat, count: Int, flip: Bool) -> some View {
        let long = r * 0.62
        return Text(title)
            .font(.system(size: count > 16 ? 9 : count > 8 ? 11 : 13, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: long)
            .rotationEffect(.degrees(flip ? -90 : 90))
            .frame(width: 18, height: long)
            .padding(.top, r * 0.12)
            .frame(height: r * 2, alignment: .top)
    }
}

private struct Slice: Shape {
    let start: Angle
    let end: Angle

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var p = Path()
        if end.degrees - start.degrees >= 359.9 { p.addEllipse(in: rect); return p }
        p.move(to: c)
        p.addArc(center: c, radius: min(rect.width, rect.height) / 2, startAngle: start, endAngle: end, clockwise: false)
        p.closeSubpath()
        return p
    }
}

/// A teardrop pin pointing down into the wheel.
private struct Pointer: Shape {
    func path(in rect: CGRect) -> Path {
        let r = rect.width / 2
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: r), radius: r, startAngle: .degrees(150), endAngle: .degrees(30), clockwise: false)
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
