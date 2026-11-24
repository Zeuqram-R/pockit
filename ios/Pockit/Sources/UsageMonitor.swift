import SwiftUI
import WebKit

/// Uso de Claude (sesión y semanal). Lo lee de la página de Ajustes → Uso de claude.ai en una vista web
/// escondida (con la misma sesión iniciada), igual que si Jose la abriera; no llama a nada interno.
@MainActor
final class UsageMonitor: NSObject, ObservableObject, WKNavigationDelegate {
    static let shared = UsageMonitor()

    @Published private(set) var session: Int?
    @Published private(set) var weekly: Int?
    @Published private(set) var updatedAt: Date?
    @Published private(set) var problem: String?

    private var web: WKWebView?
    private var timer: Timer?
    private var loading = false
    private var lastLoad = Date.distantPast
    private let url = URL(string: "https://claude.ai/settings/usage")!

    override init() {
        super.init()
        let d = UserDefaults.standard
        if d.object(forKey: "pk.usage.s") != nil { session = d.integer(forKey: "pk.usage.s") }
        if d.object(forKey: "pk.usage.w") != nil { weekly = d.integer(forKey: "pk.usage.w") }
        if let t = d.object(forKey: "pk.usage.t") as? Date { updatedAt = t }
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task { @MainActor in UsageMonitor.shared.refresh() }
        }
        refresh()
    }

    /// Lo que dice el aviso del chat ("Has usado 81% de tu límite semanal") se usa de una vez.
    func fromBanner(kind: String, pct: Int) {
        if kind == "session" { session = pct } else { weekly = pct }
        save()
    }

    func refresh(force: Bool = false) {
        guard !loading, force || Date().timeIntervalSince(lastLoad) > 45 else { return }
        loading = true
        lastLoad = Date()
        let wv = web ?? makeWeb()
        wv.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 25))
    }

    private func makeWeb() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.preferredContentMode = .mobile
        let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 800), configuration: config)
        wv.navigationDelegate = self
        wv.isUserInteractionEnabled = false
        wv.alpha = 0.01
        // pegada a la ventana (fuera de la pantalla) pa' que iOS no le congele los relojes de la página
        if let win = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first {
            wv.frame.origin = CGPoint(x: -2000, y: 0)
            win.addSubview(wv)
        }
        web = wv
        return wv
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in self.poll(tries: 0) }
    }
    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in self.loading = false }
    }
    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in self.loading = false }
    }

    /// La página arma su contenido después de cargar; se revisa cada segundo hasta 15 s.
    private func poll(tries: Int) {
        guard let web else { loading = false; return }
        web.evaluateJavaScript(Self.readJS) { [weak self] result, _ in
            Task { @MainActor in
                guard let self else { return }
                let str = result as? String ?? ""
                let obj = (try? JSONSerialization.jsonObject(with: Data(str.utf8))) as? [String: Any] ?? [:]
                if obj["login"] as? Bool == true { self.problem = "login"; self.finish(); return }
                let s = obj["s"] as? Int, w = obj["w"] as? Int
                if s != nil || w != nil {
                    if let s { self.session = s }
                    if let w { self.weekly = w }
                    self.problem = nil
                    self.save()
                    self.finish()
                } else if tries < 15 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.poll(tries: tries + 1) }
                } else {
                    self.problem = "parse"
                    self.finish()
                }
            }
        }
    }

    private func finish() {
        loading = false
        web?.loadHTMLString("", baseURL: nil)   // suelta la página pa' no gastar batería
    }

    private func save() {
        updatedAt = Date()
        let d = UserDefaults.standard
        if let session { d.set(session, forKey: "pk.usage.s") }
        if let weekly { d.set(weekly, forKey: "pk.usage.w") }
        d.set(updatedAt, forKey: "pk.usage.t")
    }

    static let readJS = """
    (function(){
      if (/\\/login/.test(location.pathname)) return JSON.stringify({login:true});
      var root = document.querySelector('main') || document.body;
      var lines = (root.innerText || '').split('\\n').map(function(s){return s.trim();}).filter(Boolean);
      var out = {}, label = '';
      for (var i = 0; i < lines.length; i++) {
        var l = lines[i];
        if (/sesi[oó]n actual|current session/i.test(l)) label = 's';
        else if (/todos los modelos|all models/i.test(l)) label = 'w';
        else if (/l[ií]mites? semanal|weekly limit/i.test(l) && !label) label = 'w';
        else if (/(^|\\s)(sonnet|opus|haiku|fable|design)\\b|solo |only/i.test(l) && label === 'w' && out.w != null) label = 'x';
        var m = l.match(/(\\d{1,3})\\s*%/);
        if (m && (label === 's' || label === 'w') && out[label] == null) out[label] = Math.min(100, parseInt(m[1], 10));
      }
      if (out.s == null || out.w == null) {
        var bars = document.querySelectorAll('[role=progressbar][aria-valuenow]');
        bars.forEach(function(b){
          var ctx = ((b.closest('section,li,div') || b).innerText || '') + ' ' + (b.getAttribute('aria-label') || '');
          var v = Math.round(parseFloat(b.getAttribute('aria-valuenow')));
          if (/sesi|session/i.test(ctx) && out.s == null) out.s = v;
          else if (/seman|week|all models|todos/i.test(ctx) && out.w == null) out.w = v;
        });
      }
      return JSON.stringify(out);
    })()
    """
}

/// Anillo doble como el de Claude Code: afuera el uso semanal, adentro el de la sesión.
/// Al tocarlo sale una burbujita a la derecha con los dos porcentajes.
struct UsageRing: View {
    @ObservedObject var usage = UsageMonitor.shared
    @EnvironmentObject private var settings: AppSettings
    @State private var showBubble = false

    private func color(_ v: Int?) -> Color {
        guard let v else { return Theme.lilac }
        if v >= 90 { return Color(red: 1, green: 0.32, blue: 0.36) }
        if v >= 75 { return Theme.sunset }
        return Theme.switchPink
    }

    var body: some View {
        let t = settings.t
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showBubble.toggle() }
            if showBubble { usage.refresh() }
        } label: {
            ZStack {
                Circle().fill(Theme.nightDeep.opacity(0.45))
                ring(usage.weekly, width: 4).padding(3)
                ring(usage.session, width: 3.5).padding(10)
            }
            .frame(width: 36, height: 36)
            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(t.s("Uso de Claude", "Claude usage"))
        .accessibilityValue("\(t.s("Semanal", "Weekly")) \(usage.weekly.map { "\($0)%" } ?? "—"), \(t.s("Sesión", "Session")) \(usage.session.map { "\($0)%" } ?? "—")")
        .overlay(alignment: .leading) {
            if showBubble {
                VStack(alignment: .leading, spacing: 3) {
                    row(t.s("Semanal", "Weekly"), usage.weekly)
                    row(t.s("Sesión", "Session"), usage.session)
                    if usage.problem == "login" {
                        Text(t.s("Iniciá sesión en Claude", "Sign in to Claude")).font(Theme.text(10, .regular)).foregroundStyle(Theme.lilac)
                    } else if let u = usage.updatedAt {
                        Text(u, style: .relative).font(Theme.text(10, .regular)).foregroundStyle(Theme.lilac)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.ultraThinMaterial))
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.nightDeep.opacity(0.6)))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 1))
                .fixedSize()
                .offset(x: 44)
                .transition(.scale(scale: 0.6, anchor: .leading).combined(with: .opacity))
                .onTapGesture { withAnimation { showBubble = false } }
                .task {
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    withAnimation { showBubble = false }
                }
            }
        }
        .zIndex(5)
    }

    private func ring(_ v: Int?, width: CGFloat) -> some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.14), lineWidth: width)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(v ?? 0, 0), 100)) / 100)
                .stroke(color(v), style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: v)
        }
    }

    private func row(_ title: String, _ v: Int?) -> some View {
        HStack(spacing: 6) {
            Text("\(title):").font(Theme.text(12, .regular)).foregroundStyle(Theme.lilac)
            Text(v.map { "\($0)%" } ?? "—").font(Theme.text(12, .semibold)).foregroundStyle(color(v))
        }
    }
}
