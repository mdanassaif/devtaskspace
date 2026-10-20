// Site logos for domains, subscriptions and products. Fetched once from DuckDuckGo's icon service, then cached on disk.
import SwiftUI
import AppKit

@MainActor
final class Favicons: ObservableObject {
    static let shared = Favicons()
    @Published private var images: [String: NSImage] = [:]
    private var started: Set<String> = []
    private let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("com.anashq.app/icons")

    /// The logo if it's ready; otherwise starts loading it and returns nil (the view shows initials meanwhile).
    func image(_ raw: String) -> NSImage? {
        let d = Favicons.clean(raw)
        guard !d.isEmpty else { return nil }
        if let i = images[d] { return i }
        if !started.contains(d) {
            started.insert(d)
            Task { await load(d) }
        }
        return nil
    }

    private func load(_ d: String) async {
        let file = dir.appendingPathComponent(d + ".ico"), none = dir.appendingPathComponent(d + ".none")
        if let data = try? Data(contentsOf: file), let img = NSImage(data: data) { images[d] = img; return }
        // Sites without a logo are retried after a week.
        if let at = (try? FileManager.default.attributesOfItem(atPath: none.path))?[.modificationDate] as? Date, Date().timeIntervalSince(at) < 7 * 86_400 { return }
        guard let url = URL(string: "https://icons.duckduckgo.com/ip3/\(d).ico"),
              let (data, resp) = try? await URLSession.shared.data(from: url) else { started.remove(d); return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if (resp as? HTTPURLResponse)?.statusCode == 200, let img = NSImage(data: data) {
            try? data.write(to: file)
            images[d] = img
        } else {
            FileManager.default.createFile(atPath: none.path, contents: Data())
        }
    }

    static func clean(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespaces).lowercased()
        if let u = URL(string: t.contains("://") ? t : "https://" + t), let h = u.host { t = h }
        if t.hasPrefix("www.") { t = String(t.dropFirst(4)) }
        return t.contains(".") && !t.contains(" ") ? t : ""
    }

    /// Well-known services, so most subscriptions get a logo without typing a website.
    static let known: [String: String] = [
        "claude": "claude.ai", "anthropic": "anthropic.com", "chatgpt": "openai.com", "openai": "openai.com", "cursor": "cursor.com",
        "cloudflare": "cloudflare.com", "hetzner": "hetzner.com", "railway": "railway.app", "vercel": "vercel.com", "netlify": "netlify.com",
        "supabase": "supabase.com", "github": "github.com", "copilot": "github.com", "figma": "figma.com", "canva": "canva.com",
        "notion": "notion.so", "linear": "linear.app", "slack": "slack.com", "google workspace": "workspace.google.com", "google one": "one.google.com",
        "medium": "medium.com", "netflix": "netflix.com", "spotify": "spotify.com", "youtube": "youtube.com", "prime": "primevideo.com",
        "apple": "apple.com", "icloud": "icloud.com", "x premium": "x.com", "twitter": "x.com", "resend": "resend.com",
        "plausible": "plausible.io", "ahrefs": "ahrefs.com", "semrush": "semrush.com", "namecheap": "namecheap.com", "spaceship": "spaceship.com",
        "dodo": "dodopayments.com", "stripe": "stripe.com", "lemon squeezy": "lemonsqueezy.com", "gumroad": "gumroad.com", "framer": "framer.com",
        "webflow": "webflow.com", "zoom": "zoom.us", "dropbox": "dropbox.com", "1password": "1password.com", "grammarly": "grammarly.com",
    ]

    /// Website for a subscription: the Website field, else a known service name.
    static func site(forSub s: Record) -> String {
        if !clean(s["website"]).isEmpty { return s["website"] }
        let n = s["name"].lowercased()
        if let k = known.keys.sorted(by: { $0.count > $1.count }).first(where: { n.contains($0) }) { return known[k]! }
        return ""
    }
}

/// A site's logo on a white tile, or the initials circle when there's no logo.
struct SiteIcon: View {
    @ObservedObject private var fav = Favicons.shared
    let site: String
    let name: String
    var key: String? = nil
    var body: some View {
        if let img = fav.image(site) {
            Image(nsImage: img)
                .resizable().interpolation(.high).aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.black.opacity(0.08)))
        } else {
            Avatar(text: name, key: key)
        }
    }
}

/// Is the website behind a domain up? Checked in the background, at most every 30 minutes.
@MainActor
final class SiteStatus: ObservableObject {
    static let shared = SiteStatus()
    enum State { case live, down }
    @Published private(set) var states: [String: State] = [:]
    private var checkedAt: [String: Date] = [:]

    func state(_ domain: String) -> State? {
        let d = Favicons.clean(domain)
        guard !d.isEmpty else { return nil }
        if Date().timeIntervalSince(checkedAt[d] ?? .distantPast) > 1800 {
            checkedAt[d] = Date()
            Task { await check(d) }
        }
        return states[d]
    }

    private func check(_ d: String) async {
        var ok = false
        for scheme in ["https", "http"] where !ok {
            var req = URLRequest(url: URL(string: "\(scheme)://\(d)")!, timeoutInterval: 10)
            req.httpMethod = "GET"
            req.setValue("Mozilla/5.0 (Macintosh) AnasHQ", forHTTPHeaderField: "User-Agent")
            if let (_, r) = try? await URLSession.shared.data(for: req), let code = (r as? HTTPURLResponse)?.statusCode { ok = code < 400 }
        }
        states[d] = ok ? .live : .down
    }
}
