// Dates (stored as YYYY-MM-DD, local time) and the rules ported from the web version.
import Foundation
import SwiftUI

enum Dates {
    static let ymd: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f }()
    private static let shortF: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MMM d"; return f }()
    private static let shortYF: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f }()
    private static let dayF: DateFormatter = { let f = DateFormatter(); f.dateFormat = "EEE, MMM d"; return f }()
    private static let monthF: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MMM yyyy"; return f }()
    static let cal = Calendar.current

    static func today() -> String { ymd.string(from: Date()) }
    static func date(_ s: String) -> Date? { s.count == 10 ? ymd.date(from: s) : nil }
    static func isDate(_ s: String) -> Bool { date(s) != nil }
    static func add(_ s: String, days: Int) -> String { guard let d = date(s) else { return s }; return ymd.string(from: cal.date(byAdding: .day, value: days, to: d)!) }
    static func add(_ s: String, months: Int) -> String { guard let d = date(s) else { return s }; return ymd.string(from: cal.date(byAdding: .month, value: months, to: d)!) }
    static func diff(_ a: String, _ b: String) -> Int {
        guard let x = date(a), let y = date(b) else { return 0 }
        return cal.dateComponents([.day], from: cal.startOfDay(for: y), to: cal.startOfDay(for: x)).day ?? 0
    }
    static func short(_ s: String) -> String {
        guard let d = date(s) else { return "" }
        return (cal.component(.year, from: d) == cal.component(.year, from: Date()) ? shortF : shortYF).string(from: d)
    }
    static func day(_ s: String) -> String { date(s).map { dayF.string(from: $0) } ?? s }
    static func month(_ m: String) -> String { date(m + "-01").map { monthF.string(from: $0) } ?? m }
    static func rel(_ s: String) -> String {
        guard isDate(s) else { return "" }
        let n = diff(s, today())
        switch n {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case -1: return "Yesterday"
        case 2...59: return "in \(n)d"
        case 60...: return "in \(n / 30)mo"
        case -59 ... -2: return "\(-n)d ago"
        default: return "\(-n / 30)mo ago"
        }
    }
    static func isoDay(_ iso: String) -> String {
        if let d = ISO8601DateFormatter().date(from: iso) { return ymd.string(from: d) }
        return String(iso.prefix(10))
    }
}

enum Pri: String, CaseIterable {
    case urgent, high, normal, low
    var label: String { rawValue.capitalized }
    var color: Color { switch self { case .urgent: .red; case .high: .orange; case .normal: .accentColor; case .low: .secondary } }
    var weight: Int { switch self { case .urgent: 0; case .high: 1; case .normal: 2; case .low: 3 } }
}

enum Bucket: String, CaseIterable {
    case overdue, today, tomorrow, week, later, nodate
    var label: String { ["overdue": "Overdue", "today": "Today", "tomorrow": "Tomorrow", "week": "Next 7 days", "later": "Later", "nodate": "No date"][rawValue]! }
}

enum DomStatus: String, CaseIterable {
    case active, expiring, expired, parked
    var label: String { rawValue == "expiring" ? "Expiring soon" : rawValue.capitalized }
    var color: Color { switch self { case .active: .green; case .expiring: .orange; case .expired: .red; case .parked: .secondary } }
}

enum SubStatus: String, CaseIterable {
    case active, trial, paused, cancelled
    var label: String { rawValue.capitalized }
    var color: Color { switch self { case .active: .green; case .trial: .purple; case .paused: .orange; case .cancelled: .secondary } }
}

let cycles = ["weekly": "/wk", "monthly": "/mo", "quarterly": "/qtr", "yearly": "/yr"]
let cycleOrder = ["weekly", "monthly", "quarterly", "yearly"]

enum Logic {
    static func pri(_ t: Record) -> Pri { Pri(rawValue: t["pri"]) ?? .normal }

    static func bucket(_ t: Record) -> Bucket {
        let due = t["due"], t0 = Dates.today()
        guard Dates.isDate(due) else { return .nodate }
        if due < t0 { return .overdue }
        if due == t0 { return .today }
        if due == Dates.add(t0, days: 1) { return .tomorrow }
        if due <= Dates.add(t0, days: 7) { return .week }
        return .later
    }

    static func taskSort(_ a: Record, _ b: Record) -> Bool {
        let da = a["due"].isEmpty ? "9999" : a["due"], db = b["due"].isEmpty ? "9999" : b["due"]
        if da != db { return da < db }
        if pri(a).weight != pri(b).weight { return pri(a).weight < pri(b).weight }
        return a["created"] < b["created"]
    }

    static func step(_ s: String, _ rep: String) -> String {
        switch rep {
        case "daily": return Dates.add(s, days: 1)
        case "weekly": return Dates.add(s, days: 7)
        case "monthly": return Dates.add(s, months: 1)
        case "yearly": return Dates.add(s, months: 12)
        default: return s
        }
    }

    static func domStatus(_ d: Record) -> DomStatus {
        if d.flag("parked") { return .parked }
        guard Dates.isDate(d["expires"]) else { return .active }
        let n = Dates.diff(d["expires"], Dates.today())
        if n < 0 { return .expired }
        if n <= 30 { return .expiring }
        return .active
    }

    static func subStatus(_ s: Record) -> SubStatus { SubStatus(rawValue: s["status"]) ?? .active }
    static func isLive(_ s: Record) -> Bool { [.active, .trial].contains(subStatus(s)) }
    static func monthly(_ s: Record) -> Double {
        let a = s.num("amount")
        switch s["cycle"] { case "yearly": return a / 12; case "quarterly": return a / 3; case "weekly": return a * 52 / 12; default: return a }
    }
    static func subNext(_ s: Record) -> String {
        if [.cancelled, .paused].contains(subStatus(s)) { return "" }
        let anchor = s["renews"], t0 = Dates.today()
        guard Dates.isDate(anchor) else { return "" }
        var n = anchor, g = 0
        let cyc = s["cycle"].isEmpty ? "monthly" : s["cycle"]
        while n < t0 && g < 2000 {
            n = cyc == "weekly" ? Dates.add(n, days: 7) : Dates.add(n, months: cyc == "yearly" ? 12 : cyc == "quarterly" ? 3 : 1)
            g += 1
        }
        return n
    }

    static func r2(_ n: Double) -> Double { (n * 100).rounded() / 100 }

    /// Natural-language quick add: dates ("fri", "oct 25", "in 3d"), #project, !priority.
    static func parseQuick(_ str: String, projects: [String]) -> (title: String, due: String, pri: String, project: String) {
        var s = " " + str + " "
        var due = "", pri = "", project = ""
        let t0 = Dates.today()

        func firstMatch(_ pattern: String) -> [String]? {
            guard let re = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
            return (0..<m.numberOfRanges).map { i in Range(m.range(at: i), in: s).map { String(s[$0]) } ?? "" }
        }
        func strip(_ whole: String) { if let r = s.range(of: whole) { s.replaceSubrange(r, with: " ") } }
        func take(_ pattern: String, _ fn: ([String]) -> String) {
            guard due.isEmpty, let m = firstMatch(pattern) else { return }
            let r = fn(m); if !r.isEmpty { due = r; strip(m[0]) }
        }
        func nextWeekday(_ dow: Int) -> String { // 1 = Sunday
            let cur = Dates.cal.component(.weekday, from: Date())
            var n = (dow - cur + 7) % 7; if n == 0 { n = 7 }
            return Dates.add(t0, days: n)
        }

        if let m = firstMatch(#"\s!(urgent|high|normal|low|u|h|n|l|1|2|3|4)(?=\s)"#) {
            let k = m[1].lowercased()
            pri = ["u": "urgent", "1": "urgent", "h": "high", "2": "high", "n": "normal", "3": "normal", "l": "low", "4": "low"][k] ?? k
            strip(m[0])
        }
        if let m = firstMatch(#"\s#([\w.\-]+)(?=\s)"#) {
            let slug = { (x: String) in x.lowercased().filter { $0.isLetter || $0.isNumber } }
            let want = slug(m[1])
            project = projects.first { slug($0) == want } ?? projects.first { slug($0).hasPrefix(want) } ?? m[1]
            strip(m[0])
        }
        take(#"\s(\d{4}-\d{2}-\d{2})(?=\s)"#) { $0[1] }
        take(#"\s(today|tod|tonight)(?=\s)"#) { _ in t0 }
        take(#"\s(tomorrow|tmrw|tmr)(?=\s)"#) { _ in Dates.add(t0, days: 1) }
        take(#"\snext week(?=\s)"#) { _ in nextWeekday(2) }
        take(#"\sin (\d{1,3}) ?(d|days?|w|wks?|weeks?|mo|months?)(?=\s)"#) { m in
            let n = Int(m[1]) ?? 0, u = m[2].lowercased()
            return u.hasPrefix("w") ? Dates.add(t0, days: n * 7) : u.hasPrefix("m") ? Dates.add(t0, months: n) : Dates.add(t0, days: n)
        }
        let mon = #"(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sept?(?:ember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\.?"#
        func md(_ mo: String, _ dd: String) -> String {
            let names = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
            guard let mi = names.firstIndex(of: String(mo.lowercased().prefix(3))), let d = Int(dd), (1...31).contains(d) else { return "" }
            let y = Dates.cal.component(.year, from: Date())
            var c = String(format: "%04d-%02d-%02d", y, mi + 1, d)
            if c < t0 { c = String(format: "%04d-%02d-%02d", y + 1, mi + 1, d) }
            return c
        }
        take(#"\s"# + mon + #" (\d{1,2})(?:st|nd|rd|th)?(?=\s)"#) { md($0[1], $0[2]) }
        take(#"\s(\d{1,2})(?:st|nd|rd|th)? "# + mon + #"(?=\s)"#) { md($0[2], $0[1]) }
        let full = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        take(#"\s(?:on |by |due )?(sunday|monday|tuesday|wednesday|thursday|friday|saturday)(?=\s)"#) { nextWeekday((full.firstIndex(of: $0[1].lowercased()) ?? 0) + 1) }
        let shortD = ["sun": 1, "mon": 2, "tue": 3, "tues": 3, "wed": 4, "thu": 5, "thur": 5, "thurs": 5, "fri": 6, "sat": 7]
        take(#"\s(?:on |by |due )?(sun|mon|tue|tues|wed|thu|thur|thurs|fri|sat)\s*$"#) { nextWeekday(shortD[$0[1].lowercased()] ?? 1) }

        let title = s.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return (title, due, pri, project)
    }
}

// MARK: shared look

/// Stable colour per name, for avatars and project dots.
func hueColor(_ s: String) -> Color {
    let palette: [Color] = [.green, .orange, .red, .purple, .blue, .pink, .teal, .yellow, .indigo, .mint]
    var h: UInt32 = 7
    for c in (s.isEmpty ? "?" : s).lowercased().unicodeScalars { h = h &* 31 &+ c.value }
    return palette[Int(h % UInt32(palette.count))]
}

func initials(_ s: String) -> String {
    let clean = s.replacingOccurrences(of: #"^https?://|^www\."#, with: "", options: .regularExpression)
    let words = clean.split { !$0.isLetter && !$0.isNumber }
    if words.count >= 2, let a = words[0].first, let b = words[1].first, !clean.contains(".") { return String([a, b]).uppercased() }
    return String(clean.filter { $0.isLetter || $0.isNumber }.prefix(2)).uppercased()
}
