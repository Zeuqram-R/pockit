import SwiftUI
import WebKit

/// Skin A+: descarga theme.css y config.json de pockit-skin, los guarda pa' usar sin internet
/// y los inyecta en claude.ai. Se apaga con el switch local o con skinEnabled=false remoto.
@MainActor
final class SkinManager: ObservableObject {
    private static let base = "https://raw.githubusercontent.com/Zeuqram-R/pockit-skin/refs/heads/main/"

    @AppStorage("pockit.skin.local") var localEnabled = true {
        willSet { objectWillChange.send() }
        didSet { apply() }
    }
    @AppStorage("pockit.skin.remote") private var remoteEnabled = true
    @AppStorage("pockit.skin.css") private var cachedCSS = ""
    @AppStorage("pockit.skin.version") private(set) var cssVersion = 0

    @Published private(set) var lastStatus = ""

    private weak var web: WebModel?

    var isActive: Bool { localEnabled && remoteEnabled }
    var remoteSaysOff: Bool { !remoteEnabled }

    func attach(_ web: WebModel) {
        self.web = web
        apply()
        Task { await refresh() }
    }

    func refresh() async {
        do {
            let stamp = Int(Date().timeIntervalSince1970)
            let config = try await fetch("config.json?t=\(stamp)")
            if let json = try JSONSerialization.jsonObject(with: config) as? [String: Any] {
                remoteEnabled = (json["skinEnabled"] as? Bool) ?? true
                let version = (json["cssVersion"] as? Int) ?? 0
                if version != cssVersion || cachedCSS.isEmpty {
                    let css = try await fetch("theme.css?v=\(version)")
                    cachedCSS = String(decoding: css, as: UTF8.self)
                    cssVersion = version
                }
            }
            lastStatus = "ok v\(cssVersion)"
        } catch {
            lastStatus = "sin conexión, usando copia guardada"
        }
        objectWillChange.send()
        apply()
    }

    private func fetch(_ path: String) async throws -> Data {
        var request = URLRequest(url: URL(string: Self.base + path)!)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }

    private var css: String {
        if !cachedCSS.isEmpty { return cachedCSS }
        if let url = Bundle.main.url(forResource: "theme-fallback", withExtension: "css"),
           let s = try? String(contentsOf: url, encoding: .utf8) { return s }
        return ""
    }

    /// Pone o quita el <style id="pockit-skin"> en la página actual y en las próximas.
    func apply() {
        guard let web else { return }
        let content = isActive ? css : ""
        let js = """
        (function(){
          var css = \(WebModel.jsString(content));
          var el = document.getElementById('pockit-skin');
          if (!css) { if (el) el.remove(); return; }
          if (!el) { el = document.createElement('style'); el.id = 'pockit-skin'; (document.head || document.documentElement).appendChild(el); }
          if (el.textContent !== css) el.textContent = css;
        })();
        """
        let script = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        web.setExtraScripts([script])
        web.run(js)
    }
}
