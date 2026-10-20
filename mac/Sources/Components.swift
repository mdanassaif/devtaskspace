// Shared building blocks: cards, stat tiles, list rows, chart, empty states.
import SwiftUI
import Charts

extension View {
    func card() -> some View {
        self.background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(nsColor: .separatorColor).opacity(0.6)))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct Stat: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    var foot: String = ""
    var valueColor: Color = .primary
    var footColor: Color = .secondary
}

struct StatRow: View {
    let stats: [Stat]
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.element.id) { i, s in
                if i > 0 { Divider() }
                VStack(alignment: .leading, spacing: 6) {
                    Text(s.label).font(.callout).foregroundStyle(.secondary)
                    Text(s.value).font(.system(size: 24, weight: .semibold)).foregroundStyle(s.valueColor).lineLimit(1).minimumScaleFactor(0.6)
                    Text(s.foot.isEmpty ? " " : s.foot).font(.caption).foregroundStyle(s.footColor).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .card()
    }
}

struct Avatar: View {
    let text: String
    var key: String? = nil
    var body: some View {
        let c = hueColor(key ?? text)
        Text(initials(text))
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(c)
            .frame(width: 30, height: 30)
            .background(Circle().fill(c.opacity(0.15)))
    }
}

struct Pill: View {
    let label: String
    let color: Color
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.caption.weight(.medium))
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .overlay(Capsule().strokeBorder(Color(nsColor: .separatorColor)))
    }
}

/// Small coloured dot followed by the label text.
struct DotLabel: LabelStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            configuration.title
        }
    }
}

struct ProjectTag: View {
    let name: String
    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(hueColor(name)).frame(width: 7, height: 7)
            Text(name)
        }
    }
}

/// One line in a list. Tap opens the editor; right-click offers edit and delete.
struct Row<Lead: View, Meta: View>: View {
    @EnvironmentObject var store: Store
    let kind: Kind
    let record: Record
    let title: String
    var subtitle: [String] = []
    var project: String = ""
    var whenMain: String = ""
    var whenSub: String = ""
    var whenColor: Color = .primary
    var dim = false
    @ViewBuilder var lead: () -> Lead
    @ViewBuilder var meta: () -> Meta
    @State private var hover = false

    var body: some View {
        HStack(spacing: 14) {
            lead()
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body.weight(.medium)).lineLimit(1).strikethrough(dim).foregroundStyle(dim ? .secondary : .primary)
                if !project.isEmpty || !subtitle.isEmpty {
                    HStack(spacing: 6) {
                        if !project.isEmpty { ProjectTag(name: project) }
                        ForEach(Array(subtitle.enumerated()), id: \.offset) { i, s in
                            if i > 0 || !project.isEmpty { Text("·") }
                            Text(s).lineLimit(1)
                        }
                    }
                    .font(.callout).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            meta()
            if !whenMain.isEmpty || !whenSub.isEmpty {
                VStack(alignment: .trailing, spacing: 2) {
                    if !whenMain.isEmpty { Text(whenMain).font(.callout.weight(.medium)).foregroundStyle(whenColor) }
                    if !whenSub.isEmpty { Text(whenSub).font(.caption).foregroundStyle(whenColor == .primary ? .secondary : whenColor) }
                }
                .frame(minWidth: 90, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
        .contentShape(Rectangle())
        .background(hover ? Color.primary.opacity(0.04) : .clear)
        .onHover { hover = $0 }
        .onTapGesture { store.editing = EditTarget(kind: kind, record: record) }
        .contextMenu {
            Button("Edit…") { store.editing = EditTarget(kind: kind, record: record) }
            Divider()
            Button("Delete", role: .destructive) { store.delete(kind, record.id); store.show("Deleted “\(title)”") }
        }
    }
}

struct GroupHeader: View {
    let title: String
    var right: String = ""
    var color: Color = .secondary
    var body: some View {
        HStack {
            Text(title.uppercased()).font(.caption.weight(.semibold)).tracking(0.6).foregroundStyle(color)
            Spacer()
            Text(right).font(.caption.weight(.medium)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
    }
}

/// A bordered list panel with dividers between children.
struct Panel<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(spacing: 0) { content() }
            .frame(maxWidth: .infinity)
            .card()
    }
}

/// One quiet line for an empty panel where a full empty state would be too loud.
struct EmptyLine: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(.tertiary)
            Text(text).foregroundStyle(.secondary)
            Spacer()
        }
        .font(.callout)
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let text: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 22)).foregroundStyle(.secondary)
                .frame(width: 46, height: 46).background(Circle().strokeBorder(Color(nsColor: .separatorColor)))
            Text(title).font(.headline)
            Text(text).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 380)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 36)
    }
}

struct Point: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

/// Bar chart by day or month; hover shows the exact value.
struct BarChart: View {
    @EnvironmentObject var store: Store
    let title: String
    let total: String
    let points: [Point]
    var unit: Calendar.Component = .day
    var tint: Color = .green
    var height: CGFloat = 190
    @State private var selected: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title.uppercased()).font(.caption.weight(.semibold)).tracking(0.6).foregroundStyle(.secondary)
                Spacer()
                Text(total).font(.callout.weight(.medium))
            }
            Chart {
                ForEach(points) { p in
                    BarMark(x: .value("Date", p.date, unit: unit), y: .value("Amount", p.value))
                        .foregroundStyle(p.value < 0 ? Color.red : (isNow(p.date) ? tint : tint.opacity(0.45)))
                        .cornerRadius(2)
                }
                if let s = selected, let p = nearest(s) {
                    RuleMark(x: .value("Date", p.date, unit: unit))
                        .foregroundStyle(Color.secondary.opacity(0.25))
                        .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                            VStack(spacing: 2) {
                                Text(label(p.date)).font(.caption).foregroundStyle(.secondary)
                                Text(store.money(p.value)).font(.callout.weight(.semibold))
                            }
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 7).fill(Color(nsColor: .windowBackgroundColor)).shadow(radius: 3))
                        }
                }
            }
            .chartXSelection(value: $selected)
            .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: height < 160 ? 3 : 5)) { v in AxisGridLine(); AxisValueLabel { if let d = v.as(Double.self) { Text(store.money(d, compact: true)) } } } }
            .frame(height: height)
        }
        .padding(16)
        .card()
    }

    private func isNow(_ d: Date) -> Bool { Calendar.current.isDate(d, equalTo: Date(), toGranularity: unit) }
    private func nearest(_ d: Date) -> Point? { points.first { Calendar.current.isDate($0.date, equalTo: d, toGranularity: unit) } }
    private func label(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = unit == .month ? "MMMM yyyy" : "EEE, MMM d"
        return f.string(from: d)
    }
}

/// Segmented filter row used at the top of most sections.
struct FilterBar<T: Hashable>: View {
    @Binding var value: T
    let options: [(T, String)]
    var body: some View {
        Picker("", selection: $value) {
            ForEach(options, id: \.0) { Text($0.1).tag($0.0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
    }
}

/// "Add a task…" box with natural-language parsing.
struct QuickAdd: View {
    @EnvironmentObject var store: Store
    var placeholder: String
    var defaultToday: Bool
    @State private var text = ""
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus").foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .onSubmit { store.quickAddTask(text, defaultToday: defaultToday); text = "" }
            if !text.isEmpty {
                let p = Logic.parseQuick(text, projects: store.projects)
                let due = p.due.isEmpty && defaultToday ? Dates.today() : p.due
                HStack(spacing: 8) {
                    if !due.isEmpty { Label(Dates.rel(due), systemImage: "calendar") }
                    if !p.project.isEmpty { ProjectTag(name: p.project) }
                    if let pr = Pri(rawValue: p.pri) { Label(pr.label, systemImage: "flag").foregroundStyle(pr.color) }
                    Text("↩ to add").foregroundStyle(.tertiary)
                }
                .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .card()
    }
}

/// Day-by-day sums → chart points.
func dailyPoints(_ rows: [Record], dateField: String, days: Int) -> [Point] {
    var m: [String: Double] = [:]
    for r in rows { m[r[dateField], default: 0] += r.num("amount") }
    let t0 = Dates.today()
    return (0..<days).reversed().map { i in
        let d = Dates.add(t0, days: -i)
        return Point(date: Dates.date(d)!, value: Logic.r2(m[d] ?? 0))
    }
}

/// Month sums (keys "YYYY-MM") → chart points from `from` to `to`.
func monthlyPoints(_ sums: [String: Double], from: String, to: String) -> [Point] {
    var out: [Point] = []
    var cur = from, g = 0
    while cur <= to && g < 600 {
        out.append(Point(date: Dates.date(cur + "-01")!, value: Logic.r2(sums[cur] ?? 0)))
        cur = String(Dates.add(cur + "-01", months: 1).prefix(7)); g += 1
    }
    return out
}

func hit(_ q: String, _ fields: [String]) -> Bool {
    let words = q.lowercased().split(separator: " ")
    if words.isEmpty { return true }
    let hay = fields.joined(separator: " ").lowercased()
    return words.allSatisfy { hay.contains($0) }
}
