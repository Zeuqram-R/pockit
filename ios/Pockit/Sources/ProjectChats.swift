import SwiftUI
import WebKit

/// Una conversación del Project GTA VI.
struct ProjectChat: Identifiable, Hashable {
    let id: String      // uuid de la conversación
    let title: String
    let when: String    // "Hace 2 minutos", tal como lo muestra claude.ai
    var path: String { "/chat/\(id)" }
}

/// Lee la lista de conversaciones del Project GTA VI desde la página del proyecto,
/// en una WebView escondida (misma sesión), sin tocar el chat que tenés abierto.
@MainActor
final class ProjectChats: NSObject, ObservableObject, WKNavigationDelegate {
    @Published private(set) var chats: [ProjectChat] = []
    @Published private(set) var loading = false
    @Published private(set) var failed = false

    let webView: WKWebView
    private var lastRefresh: Date = .distantPast
    private static let cacheKey = "pockit.projectChats"

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.applicationNameForUserAgent = "Version/18.0 Mobile/15E148 Safari/604.1"
        config.defaultWebpagePreferences.preferredContentMode = .mobile
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: config)
        super.init()
        webView.navigationDelegate = self
        if let raw = UserDefaults.standard.array(forKey: Self.cacheKey) as? [[String: String]] {
            chats = raw.compactMap { d in
                guard let id = d["id"], let title = d["title"] else { return nil }
                return ProjectChat(id: id, title: title, when: d["when"] ?? "")
            }
        }
    }

    /// Recarga la lista (si la última vez fue hace más de `minAge` segundos).
    func refresh(minAge: TimeInterval = 20) {
        guard !loading, Date().timeIntervalSince(lastRefresh) > minAge else { return }
        loading = true
        failed = false
        lastRefresh = Date()
        webView.load(URLRequest(url: WebModel.projectURL))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { await extract() }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { done(failed: true) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { done(failed: true) }

    private func done(failed: Bool) {
        loading = false
        self.failed = failed && chats.isEmpty
    }

    /// Junta los links /chat/… de la página del proyecto (espera a que la app web los dibuje y baja pa' cargar más).
    private func extract() async {
        let js = """
        return await (async function(){
          const sleep = (ms) => new Promise(r => setTimeout(r, ms));
          const seen = new Map();
          const collect = () => {
            document.querySelectorAll('a[href*="/chat/"]').forEach(a => {
              const m = (a.getAttribute('href') || '').match(/\\/chat\\/([0-9a-f-]{20,})/i);
              if (!m || seen.has(m[1])) return;
              const lines = (a.innerText || '').split('\\n').map(s => s.trim()).filter(Boolean);
              if (!lines.length) return;
              seen.set(m[1], { id: m[1], title: lines[0], when: lines.slice(1).join(' · ') });
            });
          };
          for (let i = 0; i < 30 && !document.querySelector('a[href*="/chat/"]'); i++) await sleep(200);
          for (let i = 0; i < 6; i++) {
            collect();
            const before = seen.size;
            window.scrollTo(0, document.body.scrollHeight);
            document.querySelectorAll('*').forEach(e => { if (e.scrollHeight > e.clientHeight + 40 && e.clientHeight > 200) e.scrollTop = e.scrollHeight; });
            await sleep(500);
            collect();
            if (seen.size === before && i > 0) break;
          }
          return JSON.stringify(Array.from(seen.values()));
        })()
        """
        do {
            let result = try await webView.callAsyncJavaScript(js, contentWorld: .page)
            if let text = result as? String, let data = text.data(using: .utf8),
               let list = try JSONSerialization.jsonObject(with: data) as? [[String: String]] {
                let parsed = list.compactMap { d -> ProjectChat? in
                    guard let id = d["id"], let title = d["title"] else { return nil }
                    return ProjectChat(id: id, title: title, when: d["when"] ?? "")
                }
                if !parsed.isEmpty || chats.isEmpty {
                    chats = parsed
                    UserDefaults.standard.set(list, forKey: Self.cacheKey)
                }
            }
            done(failed: false)
        } catch {
            done(failed: true)
        }
    }
}

/// Panel de conversaciones que sale desde la izquierda (como en la app de Claude).
struct ChatsDrawer: View {
    @Binding var isOpen: Bool
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var web: WebModel
    @EnvironmentObject private var chats: ProjectChats
    @State private var query = ""
    @GestureState private var drag: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let width = min(geo.size.width * 0.84, 360)
            let offset: CGFloat = isOpen ? min(0, drag) : -width
            let dim: Double = isOpen ? 0.45 * Double(1 + offset / width) : 0
            ZStack(alignment: .leading) {
                Color.black.opacity(dim)
                    .ignoresSafeArea()
                    .onTapGesture { isOpen = false }
                    .allowsHitTesting(isOpen)

                panel(width: width)
                    .frame(width: width)
                    .offset(x: offset)
                    .gesture(
                        DragGesture()
                            .updating($drag) { v, s, _ in s = min(0, v.translation.width) }
                            .onEnded { v in if v.translation.width < -width * 0.3 || v.predictedEndTranslation.width < -width * 0.6 { isOpen = false } }
                    )
            }
            .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.86), value: isOpen)
            .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.9), value: drag)
        }
        .onChange(of: isOpen) { _, open in if open { chats.refresh() } }
    }

    private func panel(width: CGFloat) -> some View {
        let t = settings.t
        let list = chats.chats.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(t.s("CONVERSACIONES", "CHATS")).font(Theme.display(28)).foregroundStyle(.white)
                Text("Project GTA VI").font(Theme.text(13, .medium, relativeTo: .footnote)).foregroundStyle(Theme.lilac)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)

            Button {
                web.open(path: WebModel.projectURL.path)
                isOpen = false
            } label: {
                Label(t.s("Nueva conversación", "New chat"), systemImage: "square.and.pencil")
                    .font(Theme.text(16, .semibold))
                    .foregroundStyle(Theme.nightDeep)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Capsule().fill(Theme.switchPink))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 14)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.lilac)
                TextField(t.s("Buscar", "Search"), text: $query)
                    .font(Theme.text(15))
                    .foregroundStyle(.white)
                    .submitLabel(.search)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.nightDeep.opacity(0.6)))
            .padding(.horizontal, 16)
            .padding(.top, 12)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if list.isEmpty {
                        Text(chats.loading ? t.s("Cargando…", "Loading…")
                             : chats.failed ? t.s("No pude cargar la lista. Deslizá pa' abajo pa' reintentar.", "Couldn't load the list. Pull down to retry.")
                             : t.s("No hay conversaciones.", "No chats yet."))
                            .font(Theme.text(14)).foregroundStyle(Theme.lilac)
                            .padding(18)
                    }
                    ForEach(list) { chat in
                        let current = web.currentPath.hasPrefix(chat.path)
                        Button {
                            if !current { web.open(path: chat.path) }
                            isOpen = false
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(chat.title).font(Theme.text(15, current ? .semibold : .regular)).foregroundStyle(.white).lineLimit(2)
                                if !chat.when.isEmpty {
                                    Text(chat.when).font(Theme.text(11, relativeTo: .caption2)).foregroundStyle(Theme.lilac.opacity(0.85))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(current ? Theme.switchPink.opacity(0.22) : Color.clear))
                            .overlay(alignment: .leading) {
                                if current { Capsule().fill(Theme.switchPink).frame(width: 3).padding(.vertical, 8) }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .refreshable { chats.refresh(minAge: 0) }
            .overlay(alignment: .top) {
                if chats.loading && !list.isEmpty { ProgressView().tint(Theme.switchPink).padding(.top, 4) }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.menu.ignoresSafeArea())
        .overlay(alignment: .trailing) { Rectangle().fill(Theme.line).frame(width: 1).ignoresSafeArea() }
        .shadow(color: .black.opacity(0.35), radius: 18, x: 6)
    }
}
