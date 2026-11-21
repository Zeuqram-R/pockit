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
    /// Chat estilo iMessage (chat.js remoto): switch local + chatEnabled remoto.
    @AppStorage("pockit.chat.local") var chatLocalEnabled = true {
        willSet { objectWillChange.send() }
        didSet { apply() }
    }
    @AppStorage("pockit.chat.remote") private var chatRemoteEnabled = true
    @AppStorage("pockit.chat.version") private(set) var chatVersion = 0

    @Published private(set) var lastStatus = ""

    private weak var web: WebModel?

    var isActive: Bool { localEnabled && remoteEnabled }
    var chatActive: Bool { isActive && chatLocalEnabled && chatRemoteEnabled }
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
                chatRemoteEnabled = (json["chatEnabled"] as? Bool) ?? true
                let cv = (json["chatVersion"] as? Int) ?? 0
                if cv > 0, cv != chatVersion || cachedChat == nil {
                    let js = try await fetch("chat.js?v=\(cv)")
                    try? js.write(to: Self.chatCacheURL, options: .atomic)
                    chatVersion = cv
                }
            }
            lastStatus = "ok v\(cssVersion) · chat v\(chatVersion)"
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

    private static var chatCacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("pockit-chat.js")
    }

    private var cachedChat: String? {
        guard let d = try? Data(contentsOf: Self.chatCacheURL), !d.isEmpty else { return nil }
        return String(decoding: d, as: UTF8.self)
    }

    private var chatJS: String {
        if let c = cachedChat { return c }
        if let url = Bundle.main.url(forResource: "chat-fallback", withExtension: "js"),
           let s = try? String(contentsOf: url, encoding: .utf8) { return s }
        return ""
    }

    /// Pone o quita el <style id="pockit-skin"> y el chat estilo iMessage, en la página actual y en las próximas.
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
        var scripts = [WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: true)]
        if chatActive {
            let chat = chatJS
            scripts.append(WKUserScript(source: chat, injectionTime: .atDocumentStart, forMainFrameOnly: true))
            web.setExtraScripts(scripts)
            web.run(js)
            web.run(chat)
        } else {
            web.setExtraScripts(scripts)
            web.run(js)
            // Apagar el chat estilo iMessage en la página abierta: quitar su estilo y sus clases.
            web.run("(function(){var s=document.getElementById('pockit-chat');if(s)s.remove();['pk-ubub','pk-urow','pk-abub','pk-composer'].forEach(function(c){document.querySelectorAll('.'+c).forEach(function(e){e.classList.remove(c)})});window.__pockitChat=null;})();")
        }
    }
}
