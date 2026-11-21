import SwiftUI
import WebKit

/// Dueño del WKWebView: lo crea una sola vez, sigue el progreso de carga y decide qué links se abren adentro.
@MainActor
final class WebModel: NSObject, ObservableObject {
    static let projectURL = URL(string: "https://claude.ai/project/01a1f997-f69f-71ae-b0c9-abaea55a157e")!

    /// Dominios que se quedan dentro de Pockit (navegación principal). El resto se abre en Safari.
    private static let allowedHosts = ["claude.ai", "anthropic.com", "claudeusercontent.com", "cloudflare.com"]

    @Published var progress: Double = 0
    @Published var hasLoadedOnce = false
    @Published var loadError = false
    /// Aviso corto cuando un botón rápido no pudo enviar.
    @Published var sendProblem: String?

    /// Lo llama el puente JS con las etiquetas de Marisol.
    var onTags: (@MainActor ([[String: Any]]) -> Void)?
    private var prefix = ""

    let webView: WKWebView
    private var progressObservation: NSKeyValueObservation?

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        // Que claude.ai nos vea como Safari normal.
        config.applicationNameForUserAgent = "Version/18.0 Mobile/15E148 Safari/604.1"
        config.defaultWebpagePreferences.preferredContentMode = .mobile

        let content = WKUserContentController()
        if let url = Bundle.main.url(forResource: "pockit", withExtension: "js"),
           let js = try? String(contentsOf: url, encoding: .utf8) {
            content.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
        config.userContentController = content

        webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(Theme.night)
        webView.scrollView.backgroundColor = UIColor(Theme.night)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic

        super.init()
        content.add(WeakScriptHandler(self), name: "pockit")
        webView.navigationDelegate = self
        webView.uiDelegate = self
        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] wv, _ in
            Task { @MainActor in self?.progress = wv.estimatedProgress }
        }
        // Inspectable desde Safari en la Mac: así se ajusta el skin si claude.ai cambia.
        if #available(iOS 16.4, *) { webView.isInspectable = true }
        loadHome()
    }

    func loadHome() {
        loadError = false
        webView.load(URLRequest(url: Self.projectURL))
    }

    func reload() {
        loadError = false
        if webView.url == nil { loadHome() } else { webView.reload() }
    }

    /// Abre un link de acceso de claude.ai copiado del correo. Devuelve false si no es de claude.ai.
    @discardableResult
    func openSignInLink(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let host = url.host?.lowercased(),
              url.scheme == "https", Self.isAllowed(host) else { return false }
        loadError = false
        webView.load(URLRequest(url: url))
        return true
    }

    func clearSession() async {
        let store = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        await store.removeData(ofTypes: types, modifiedSince: .distantPast)
        hasLoadedOnce = false
        loadHome()
    }

    // MARK: Puente con claude.ai

    /// Prefijo ⟦device⟧ ⟦lang⟧ que va al inicio de cada mensaje.
    func setPrefix(_ value: String) {
        prefix = value
        let script = "window.__pockitPrefix = \(Self.jsString(value));"
        let ucc = webView.configuration.userContentController
        ucc.removeAllUserScripts()
        ucc.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        if let url = Bundle.main.url(forResource: "pockit", withExtension: "js"),
           let js = try? String(contentsOf: url, encoding: .utf8) {
            ucc.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
        extraScripts.forEach { ucc.addUserScript($0) }
        webView.evaluateJavaScript(script)
    }

    /// Scripts extra (el skin) que se mantienen aunque cambie el prefijo.
    private var extraScripts: [WKUserScript] = []
    func setExtraScripts(_ scripts: [WKUserScript]) {
        extraScripts = scripts
        setPrefix(prefix)
    }

    /// Escribe y envía un mensaje en el chat (botones rápidos).
    func send(_ text: String) {
        sendProblem = nil
        webView.evaluateJavaScript("window.pockitSend && window.pockitSend(\(Self.jsString(text)))")
    }

    func run(_ js: String) {
        webView.evaluateJavaScript(js)
    }

    /// Devuelve las variables de color que usa claude.ai (pa' ajustar el skin).
    func diagnose() async -> String {
        do {
            let result = try await webView.evaluateJavaScript("window.pockitDiagnose ? window.pockitDiagnose() : 'sin puente'")
            return (result as? String) ?? "sin resultado"
        } catch {
            return "error: \(error.localizedDescription)"
        }
    }

    static func jsString(_ s: String) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: [s])) ?? Data("[\"\"]".utf8)
        let arr = String(data: data, encoding: .utf8) ?? "[\"\"]"
        return String(arr.dropFirst().dropLast())
    }

    fileprivate func receive(_ body: Any) {
        guard let dict = body as? [String: Any], let type = dict["type"] as? String else { return }
        switch type {
        case "tags":
            if let items = dict["items"] as? [[String: Any]] { onTags?(items) }
        case "sendResult":
            if (dict["ok"] as? Bool) == false { sendProblem = dict["reason"] as? String ?? "?" }
        default:
            break
        }
    }

    static func isAllowed(_ host: String) -> Bool {
        allowedHosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }
}

extension WebModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else { return .allow }
        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
        let scheme = url.scheme?.lowercased() ?? ""

        if scheme == "mailto" || scheme == "tel" {
            _ = await UIApplication.shared.open(url)
            return .cancel
        }
        if isMainFrame, scheme == "https" || scheme == "http",
           let host = url.host?.lowercased(), !Self.isAllowed(host) {
            _ = await UIApplication.shared.open(url)
            return .cancel
        }
        return .allow
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        hasLoadedOnce = true
        loadError = false
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handle(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handle(error)
    }

    private func handle(_ error: Error) {
        let ns = error as NSError
        // Cancelaciones normales (otra navegación empezó) no son errores.
        if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return }
        if ns.domain == "WebKitErrorDomain" && ns.code == 102 { return }
        if !hasLoadedOnce { loadError = true }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }
}

extension WebModel: WKUIDelegate {
    /// Links con target="_blank": si son de claude.ai se abren aquí mismo; si no, en Safari.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            if let host = url.host?.lowercased(), Self.isAllowed(host) {
                webView.load(navigationAction.request)
            } else {
                UIApplication.shared.open(url)
            }
        }
        return nil
    }
}

/// Evita el ciclo de retención entre WKUserContentController y WebModel.
@MainActor
private final class WeakScriptHandler: NSObject, WKScriptMessageHandler {
    weak var target: WebModel?
    init(_ target: WebModel) { self.target = target }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.receive(message.body)
    }
}
