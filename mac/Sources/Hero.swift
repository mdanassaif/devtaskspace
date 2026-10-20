// Today's greeting banner: a calm scene that follows the time of day, plus the local weather.
import SwiftUI

enum DayPart {
    case morning, afternoon, evening, night

    static func now(_ d: Date = Date()) -> DayPart {
        switch Calendar.current.component(.hour, from: d) {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<20: return .evening
        default: return .night
        }
    }
    var greeting: String { ["Good morning", "Good afternoon", "Good evening", "Good night"][[DayPart.morning, .afternoon, .evening, .night].firstIndex(of: self)!] }
    var sky: [Color] {
        switch self {
        case .morning: return [Color(red: 0.99, green: 0.89, blue: 0.80), Color(red: 0.82, green: 0.90, blue: 0.98)]
        case .afternoon: return [Color(red: 0.70, green: 0.85, blue: 0.98), Color(red: 0.90, green: 0.95, blue: 0.99)]
        case .evening: return [Color(red: 0.55, green: 0.52, blue: 0.80), Color(red: 0.98, green: 0.74, blue: 0.62)]
        case .night: return [Color(red: 0.07, green: 0.09, blue: 0.20), Color(red: 0.18, green: 0.20, blue: 0.38)]
        }
    }
    var orb: Color {
        switch self {
        case .morning: return Color(red: 1.0, green: 0.80, blue: 0.55)
        case .afternoon: return Color(red: 1.0, green: 0.93, blue: 0.70)
        case .evening: return Color(red: 1.0, green: 0.62, blue: 0.45)
        case .night: return Color(red: 0.93, green: 0.93, blue: 0.98)
        }
    }
    /// Vertical position of the sun or moon (0 = top).
    var orbY: CGFloat { switch self { case .morning: 0.55; case .afternoon: 0.3; case .evening: 0.66; case .night: 0.32 } }
    var hills: (Color, Color) {
        switch self {
        case .morning: return (Color(red: 0.72, green: 0.85, blue: 0.78), Color(red: 0.58, green: 0.76, blue: 0.68))
        case .afternoon: return (Color(red: 0.66, green: 0.84, blue: 0.72), Color(red: 0.50, green: 0.73, blue: 0.62))
        case .evening: return (Color(red: 0.52, green: 0.43, blue: 0.62), Color(red: 0.38, green: 0.32, blue: 0.52))
        case .night: return (Color(red: 0.13, green: 0.15, blue: 0.30), Color(red: 0.09, green: 0.10, blue: 0.22))
        }
    }
    var lightText: Bool { self == .night || self == .evening }
}

@MainActor
final class Weather: ObservableObject {
    static let shared = Weather()
    @Published var temp: Double?
    @Published var code = -1
    @Published var city = ""
    private var last = Date.distantPast

    func refresh() async {
        guard Date().timeIntervalSince(last) > 1800 else { return }
        last = Date()
        do {
            let (lat, lon) = try await location()
            var c = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
            c.queryItems = [.init(name: "latitude", value: String(lat)), .init(name: "longitude", value: String(lon)),
                            .init(name: "current", value: "temperature_2m,weather_code"), .init(name: "timezone", value: "auto")]
            let (d, _) = try await URLSession.shared.data(from: c.url!)
            let o = try JSONSerialization.jsonObject(with: d) as? [String: Any]
            let cur = o?["current"] as? [String: Any]
            temp = cur?["temperature_2m"] as? Double
            code = cur?["weather_code"] as? Int ?? -1
        } catch {
            last = .distantPast // try again next time
        }
    }

    /// Approximate location from the network, cached for a day.
    private func location() async throws -> (Double, Double) {
        let ud = UserDefaults.standard
        if let t = ud.object(forKey: "geo.at") as? Date, Date().timeIntervalSince(t) < 86_400 {
            city = ud.string(forKey: "geo.city") ?? ""
            return (ud.double(forKey: "geo.lat"), ud.double(forKey: "geo.lon"))
        }
        // Two free lookups; the second is a fallback. Coordinates may come back as numbers or strings.
        var found: (Double, Double, String)?
        for src in ["https://ipwho.is/", "https://get.geojs.io/v1/ip/geo.json"] where found == nil {
            guard let (d, _) = try? await URLSession.shared.data(from: URL(string: src)!),
                  let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { continue }
            let num = { (k: String) -> Double? in (o[k] as? Double) ?? (o[k] as? String).flatMap(Double.init) }
            if let lat = num("latitude"), let lon = num("longitude") { found = (lat, lon, o["city"] as? String ?? "") }
        }
        guard let (lat, lon, c) = found else { throw URLError(.cannotFindHost) }
        city = c
        ud.set(lat, forKey: "geo.lat"); ud.set(lon, forKey: "geo.lon"); ud.set(city, forKey: "geo.city"); ud.set(Date(), forKey: "geo.at")
        return (lat, lon)
    }

    var tempText: String {
        guard let t = temp else { return "" }
        let f = MeasurementFormatter()
        f.unitOptions = .temperatureWithoutUnit
        f.numberFormatter.maximumFractionDigits = 0
        return f.string(from: Measurement(value: t, unit: UnitTemperature.celsius))
    }

    /// WMO weather codes → words and a symbol.
    func describe(night: Bool) -> (String, String) {
        switch code {
        case 0: return ("Clear", night ? "moon.stars" : "sun.max")
        case 1, 2: return ("Partly cloudy", night ? "cloud.moon" : "cloud.sun")
        case 3: return ("Cloudy", "cloud")
        case 45, 48: return ("Foggy", "cloud.fog")
        case 51...57: return ("Drizzle", "cloud.drizzle")
        case 61...67, 80...82: return ("Rain", "cloud.rain")
        case 71...77, 85, 86: return ("Snow", "cloud.snow")
        case 95...99: return ("Thunderstorm", "cloud.bolt.rain")
        default: return ("", "thermometer.medium")
        }
    }
}

struct TodayHero: View {
    @EnvironmentObject var store: Store
    @ObservedObject private var weather = Weather.shared
    @State private var now = Date()

    var body: some View {
        let part = DayPart.now(now)
        let fg: Color = part.lightText ? .white : Color(red: 0.12, green: 0.14, blue: 0.22)
        let (words, symbol) = weather.describe(night: part == .night)
        let tempText = weather.tempText

        ZStack(alignment: .leading) {
            Scenery(part: part)
            VStack(alignment: .leading, spacing: 6) {
                Text("\(part.greeting), Anas").font(.system(size: 26, weight: .semibold))
                HStack(spacing: 8) {
                    Text(Dates.day(Dates.today()))
                    if !tempText.isEmpty {
                        Text("·").opacity(0.6)
                        Image(systemName: symbol).symbolRenderingMode(.hierarchical)
                        Text(tempText).monospacedDigit()
                        if !words.isEmpty { Text(words) }
                        if !weather.city.isEmpty { Text("in \(weather.city)").opacity(0.75) }
                    }
                }
                .font(.callout)
                .opacity(0.85)
            }
            .foregroundStyle(fg)
            .padding(.horizontal, 26)
        }
        .frame(height: 132)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .task { await weather.refresh() }
        .onReceive(Timer.publish(every: 300, on: .main, in: .common).autoconnect()) { d in
            now = d
            Task { await weather.refresh() }
        }
    }
}

/// Sky gradient, a glowing sun or moon, stars at night, two layers of hills.
struct Scenery: View {
    let part: DayPart
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                LinearGradient(colors: part.sky, startPoint: .top, endPoint: .bottom)
                if part == .night {
                    ForEach(0..<28, id: \.self) { i in
                        // Fixed pseudo-random positions so stars don't jump around.
                        let x = CGFloat((i * 73) % 100) / 100, y = CGFloat((i * 37) % 60) / 100
                        Circle().fill(.white.opacity(i % 3 == 0 ? 0.8 : 0.45))
                            .frame(width: i % 4 == 0 ? 2.2 : 1.4, height: i % 4 == 0 ? 2.2 : 1.4)
                            .position(x: x * w, y: y * h)
                    }
                }
                Circle()
                    .fill(part.orb)
                    .frame(width: 46, height: 46)
                    .shadow(color: part.orb.opacity(0.9), radius: 26)
                    .position(x: w * 0.8, y: h * part.orbY)
                Hill(peak: 0.45, base: 0.80).fill(part.hills.0.opacity(0.9))
                Hill(peak: 0.72, base: 0.90).fill(part.hills.1)
            }
        }
    }
}

struct Hill: Shape {
    var peak: CGFloat   // where along the width the hill is highest
    var base: CGFloat   // height of the hill line, 0 = top
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: r.height))
        p.addLine(to: CGPoint(x: 0, y: r.height * (base + 0.12)))
        p.addCurve(to: CGPoint(x: r.width, y: r.height * (base + 0.08)),
                   control1: CGPoint(x: r.width * peak, y: r.height * (base - 0.16)),
                   control2: CGPoint(x: r.width * (peak + 0.25), y: r.height * (base + 0.2)))
        p.addLine(to: CGPoint(x: r.width, y: r.height))
        p.closeSubpath()
        return p
    }
}
