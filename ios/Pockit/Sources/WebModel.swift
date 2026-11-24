import SwiftUI
import WebKit
import Network
import ObjectiveC

/// Dueño del WKWebView: lo crea una sola vez, sigue el progreso de carga y decide qué links se abren adentro.
@MainActor
final class WebModel: NSObject, ObservableObject {
    static let projectURL = URL(string: "https://claude.ai/project/01a1f997-f69f-71ae-b0c9-abaea55a157e")!

    /// Dominios que se quedan dentro de Pockit (navegación principal). El resto se abre en Safari.
    private static let allowedHosts = ["claude.ai", "anthropic.com", "claudeusercontent.com", "cloudflare.com"]

    @Published var progress: Double = 0
    @Published var hasLoadedOnce = false
    @Published var loadError = false
    /// false cuando el teléfono pierde internet (pa' avisar en el chat)
    @Published var online = true
    /// Cuando vuelve el internet, se reintenta solo.
    private let netMonitor = NWPathMonitor()
    private var netStarted = false
    func watchNetwork() {
        guard !netStarted else { return }
        netStarted = true
        netMonitor.pathUpdateHandler = { [weak self] path in
            let ok = path.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                self.online = ok
                if ok, self.loadError, !self.hasLoadedOnce { self.loadHome() }
            }
        }
        netMonitor.start(queue: DispatchQueue(label: "pockit.net"))
    }
    /// Aviso corto cuando un botón rápido no pudo enviar.
    @Published var sendProblem: String?
    /// Ruta abierta en claude.ai (pa' marcar la conversación actual en el panel).
    @Published var currentPath = ""
    /// Marisol está escribiendo (lo avisa chat.js).
    @Published var isStreaming = false
    /// Los puntitos de escribiendo van en el retrato de Marisol (la caja tapa todo el chat).
    @Published var dotsDocked = false
    var isChatPage: Bool { currentPath.hasPrefix("/chat/") }

    /// 0.3.23: primer mensaje de una conversación nueva. claude.ai pasa de la página del proyecto al chat sin recargar
    /// y deja el layout de "chat nuevo" a medias (caja flotando, sin burbujas, sin scroll). Mientras tanto la vista nativa
    /// sigue encima (tu burbuja + puntitos); cuando Marisol termina la primera respuesta se carga el chat limpio y se destapa.
    @Published var pendingFirstMessage: String?
    private var pendingChatPath: String?
    private var pendingSawStreaming = false
    private var pendingReloading = false
    /// La vista de conversación nueva va encima de la WebView.
    var showsNewChat: Bool { isNewChat || pendingFirstMessage != nil }

    /// Lo llama el puente JS con las etiquetas de Marisol.
    var onTags: (@MainActor ([[String: Any]]) -> Void)?
    /// Lista de conversaciones del proyecto leída por chat.js.
    var onProjectChats: (@MainActor ([[String: Any]]) -> Void)?
    /// Se abrió una conversación (id, título de la pestaña).
    var onChatMissing: ((String) -> Void)?
    var onChatVisited: (@MainActor (String, String?) -> Void)?
    private var titleObservation: NSKeyValueObservation?
    private var prefix = ""

    let webView: WKWebView
    private var progressObservation: NSKeyValueObservation?
    private var zoomObservation: NSKeyValueObservation?
    private var offsetObservation: NSKeyValueObservation?
    private var keyboardTokens: [NSObjectProtocol] = []
    private var keyboardUp = false
    private var keyboardLockUntil = Date.distantPast
    private var urlObservation: NSKeyValueObservation?

    override init() {
        let config = WKWebViewConfiguration()
        WebPerf.unlock120(config.preferences)
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
        // 0.7.3: el chat no se puede pellizcar ni hacer zoom con doble toque (como una app, no como una página)
        content.addUserScript(WKUserScript(source: WebModel.noZoomJS, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.ignoresViewportScaleLimits = false
        config.userContentController = content

        webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(Theme.night)
        webView.scrollView.backgroundColor = UIColor(Theme.night)
        // El borde izquierdo abre el panel de conversaciones (no "atrás").
        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bouncesZoom = false
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false
        webView.scrollView.alwaysBounceHorizontal = false
        // "Listo" y demás botones del teclado en rosa (no azul).
        webView.tintColor = UIColor(Theme.switchPink)

        super.init()
        watchKeyboard()
        hideKeyboardAccessoryBar()
        content.add(WeakScriptHandler(self), name: "pockit")
        webView.navigationDelegate = self
        webView.uiDelegate = self
        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] wv, _ in
            Task { @MainActor in self?.progress = wv.estimatedProgress }
        }
        urlObservation = webView.observe(\.url, options: [.new]) { [weak self] wv, _ in
            Task { @MainActor in self?.urlChanged(wv) }
        }
        titleObservation = webView.observe(\.title, options: [.new]) { [weak self] wv, _ in
            Task { @MainActor in self?.urlChanged(wv) }
        }
        // Inspectable desde Safari en la Mac: así se ajusta el skin si claude.ai cambia.
        if #available(iOS 16.4, *) { webView.isInspectable = true }
        // Al abrir Pockit se retoma la última conversación (como iMessage); si no hay, conversación nueva.
        if let last = UserDefaults.standard.string(forKey: Self.lastChatKey), let url = URL(string: "https://claude.ai" + last) {
            webView.load(URLRequest(url: url))
        } else {
            loadHome()
        }
    }

    static let lastChatKey = "pockit.lastChatPath"

    /// Pantalla de conversación nueva (página del proyecto, tapada por la vista nativa).
    var isNewChat: Bool { currentPath.hasPrefix("/project/") }

    /// Adjunta un archivo al composer de claude.ai (lo recibe chat.js).
    func attach(data: Data, name: String, mime: String) async -> String {
        let js = "return window.pockitAttach ? window.pockitAttach(name, mime, b64) : 'no-chat-js'"
        let result = try? await webView.callAsyncJavaScript(js, arguments: ["name": name, "mime": mime, "b64": data.base64EncodedString()], contentWorld: .page)
        return result as? String ?? "error"
    }

    func loadHome() {
        cancelPendingNewChat()
        loadError = false
        webView.load(URLRequest(url: Self.projectURL))
    }

    private func urlChanged(_ wv: WKWebView) {
        let path = wv.url?.path ?? ""
        if path != currentPath { currentPath = path }
        if path.hasPrefix("/chat/") {
            if pendingFirstMessage != nil, pendingChatPath == nil { watchPendingChat(path) }
            UserDefaults.standard.set(path, forKey: Self.lastChatKey)
            let id = String(path.dropFirst("/chat/".count)).components(separatedBy: "/").first ?? ""
            onChatVisited?(id, wv.title)
        }
    }

    /// Abre una conversación del proyecto que claude.ai lista sin link: va a la pantalla del proyecto y toca su fila.
    func openProjectChat(title: String) {
        let call = "window.pockitOpenProjectChat ? window.pockitOpenProjectChat(\(Self.jsString(title))) : false"
        if currentPath.hasPrefix("/project/") {
            webView.evaluateJavaScript(call)
            return
        }
        open(path: Self.projectURL.path)
        Task { @MainActor in
            for _ in 0..<25 {
                try? await Task.sleep(for: .milliseconds(200))
                if let ok = try? await webView.evaluateJavaScript(call) as? Bool, ok { return }
            }
        }
    }

    /// Abre una ruta de claude.ai sin recargar toda la página cuando se puede (navegación interna de la app web).
    enum ChatAction: String { case star, rename, delete }

    /// Opciones de una conversación (destacar, renombrar, eliminar): abre la conversación y usa el mismo menú
    /// que claude.ai muestra arriba en el título, como si Jose lo tocara. Devuelve "ok" o qué faltó.
    func chatAction(_ action: ChatAction, chatID: String, newTitle: String = "") async -> String {
        let path = "/chat/\(chatID)"
        if !currentPath.hasPrefix(path) { open(path: path) }
        let js = """
        const sleep = ms => new Promise(r => setTimeout(r, ms));
        async function waitFor(fn, ms) { const t = Date.now(); while (Date.now() - t < ms) { try { const v = fn(); if (v) return v; } catch (e) {} await sleep(150); } return null; }
        const ok = await waitFor(() => location.pathname.indexOf(chatID) >= 0 && document.querySelector('[data-testid="chat-menu-trigger"], header button[aria-haspopup="menu"]'), 12000);
        if (!ok) return 'no-trigger';
        await sleep(400);
        const trig = document.querySelector('[data-testid="chat-menu-trigger"]') || document.querySelector('header button[aria-haspopup="menu"]');
        const down = { bubbles: true, cancelable: true, button: 0, pointerType: 'mouse', pointerId: 1, isPrimary: true };
        trig.dispatchEvent(new PointerEvent('pointerdown', down));
        trig.dispatchEvent(new PointerEvent('pointerup', down));
        const res = { star: /^(Destacar|Quitar de destacados|Star|Unstar|Añadir a favoritos|Quitar de favoritos|Favorite|Unfavorite)/i,
                      rename: /^(Renombrar|Cambiar nombre|Editar nombre|Rename)/i,
                      delete: /^(Eliminar|Borrar|Delete)/i }[action];
        let item = await waitFor(() => [...document.querySelectorAll('[role="menuitem"]')].find(m => res.test((m.textContent || '').trim())), 2500);
        if (!item) { trig.click(); item = await waitFor(() => [...document.querySelectorAll('[role="menuitem"]')].find(m => res.test((m.textContent || '').trim())), 2500); }
        if (!item) { document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true })); return 'no-item'; }
        item.click();
        if (action === 'rename') {
          const inp = await waitFor(() => { const a = document.activeElement; if (a && (a.tagName === 'INPUT' || a.tagName === 'TEXTAREA') && !a.closest('.ProseMirror')) return a; return document.querySelector('[role="dialog"] input, [role="dialog"] textarea, header input'); }, 3000);
          if (!inp) return 'no-input';
          const proto = inp.tagName === 'TEXTAREA' ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
          Object.getOwnPropertyDescriptor(proto, 'value').set.call(inp, newTitle);
          inp.dispatchEvent(new Event('input', { bubbles: true }));
          await sleep(150);
          const dlg = inp.closest('[role="dialog"]');
          const save = dlg && [...dlg.querySelectorAll('button')].find(b => /^(Guardar|Save|Renombrar|Rename|Listo|Done)$/i.test((b.textContent || '').trim()));
          if (save) save.click();
          else { inp.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', code: 'Enter', keyCode: 13, bubbles: true })); inp.blur(); }
        }
        if (action === 'delete') {
          const btn = await waitFor(() => [...document.querySelectorAll('[role="dialog"] button, [role="alertdialog"] button')].find(b => /^(Eliminar|Borrar|Delete)$/i.test((b.textContent || '').trim())), 3000);
          if (!btn) return 'no-confirm';
          btn.click();
        }
        return 'ok';
        """
        let r = try? await webView.callAsyncJavaScript(js, arguments: ["chatID": chatID, "action": action.rawValue, "newTitle": newTitle], contentWorld: .page)
        return (r as? String) ?? "error"
    }

    func open(path: String) {
        cancelPendingNewChat()
        loadError = false
        let js = """
        (function(p){
          try {
            if (window.next && window.next.router && typeof window.next.router.push === 'function') { window.next.router.push(p); return 'router'; }
          } catch (e) {}
          window.location.assign(p); return 'assign';
        })(\(Self.jsString(path)))
        """
        webView.evaluateJavaScript(js) { [weak self] _, error in
            if error != nil, let url = URL(string: "https://claude.ai" + path) {
                Task { @MainActor in self?.webView.load(URLRequest(url: url)) }
            }
        }
    }

    /// Manda el primer mensaje desde la pantalla de conversación nueva.
    func startNewChat(_ text: String) {
        pendingChatPath = nil
        pendingSawStreaming = false
        pendingReloading = false
        pendingFirstMessage = text
        send(text)
    }

    func cancelPendingNewChat() {
        pendingFirstMessage = nil
        pendingChatPath = nil
        pendingSawStreaming = false
        pendingReloading = false
    }

    private func watchPendingChat(_ path: String) {
        pendingChatPath = path
        Task { @MainActor in
            // Espera a que Marisol termine su primera respuesta (máximo 2 min).
            for _ in 0..<240 {
                try? await Task.sleep(for: .milliseconds(500))
                guard pendingChatPath == path, !pendingReloading else { return }
                if pendingSawStreaming && !isStreaming { break }
            }
            guard pendingChatPath == path, !pendingReloading, let url = URL(string: "https://claude.ai" + path) else { return }
            pendingReloading = true
            webView.load(URLRequest(url: url))
        }
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

    /// Al pegar, claude.ai además lee el portapapeles con navigator.clipboard y iOS mostraba el globito de "Pegar".
    /// Se instala antes que cargue claude.ai: si acabás de pegar, se le dan los datos del pegado sin preguntar.
    static let pasteShim = #"""
    (function () {
      if (window.__pkPaste || !window.Clipboard) return; window.__pkPaste = true;
      var last = null;
      document.addEventListener("paste", function (e) {
        var d = e.clipboardData; if (!d) return;
        var items = {}, text = "";
        try {
          Array.prototype.forEach.call(d.types || [], function (t) {
            if (t === "Files") return;
            var v = d.getData(t); if (t === "text/plain") text = v;
            if (v) items[t] = new Blob([v], { type: t });
          });
          Array.prototype.forEach.call(d.files || [], function (f) { if (f.type && !items[f.type]) items[f.type] = f; });
        } catch (er) {}
        last = { at: Date.now(), items: items, text: text };
      }, true);
      var fresh = function () { return last && Date.now() - last.at < 2000; };
      var P = Clipboard.prototype, oRead = P.read, oText = P.readText;
      if (oRead) P.read = function () {
        if (fresh() && window.ClipboardItem && Object.keys(last.items).length) return Promise.resolve([new ClipboardItem(last.items)]);
        return oRead.apply(this, arguments);
      };
      if (oText) P.readText = function () { return fresh() ? Promise.resolve(last.text) : oText.apply(this, arguments); };
    })();
    """#

    /// Prefijo ⟦device⟧ ⟦lang⟧ que va al inicio de cada mensaje.
    func setPrefix(_ value: String) {
        prefix = value
        let script = "window.__pockitPrefix = \(Self.jsString(value));"
        let ucc = webView.configuration.userContentController
        ucc.removeAllUserScripts()
        ucc.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        ucc.addUserScript(WKUserScript(source: Self.pasteShim, injectionTime: .atDocumentStart, forMainFrameOnly: true))
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

    func stopReply() {
        webView.evaluateJavaScript("window.pockitStop && window.pockitStop()")
    }

    func run(_ js: String) {
        webView.evaluateJavaScript(js)
    }

    /// Devuelve las variables de color que usa claude.ai (pa' ajustar el skin).
    func diagnose() async -> String {
        do {
            let result = try await webView.evaluateJavaScript("(window.pockitDiagnose ? window.pockitDiagnose() : 'sin puente') + '\\n--- chat ---\\n' + (window.pockitChatDiagnose ? window.pockitChatDiagnose() : 'chat apagado')")
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
        case "streaming":
            isStreaming = (dict["on"] as? Bool) ?? false
            if isStreaming && pendingFirstMessage != nil { pendingSawStreaming = true }
        case "copyText":
            if let t = dict["text"] as? String, !t.isEmpty { UIPasteboard.general.string = t }
        case "haptic":
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case "chatMissing":
            if let id = dict["chatID"] as? String { onChatMissing?(id) }
        case "usageBanner":
            if let pct = dict["pct"] as? Int { UsageMonitor.shared.fromBanner(kind: dict["kind"] as? String ?? "weekly", pct: pct) }
        case "dotsDocked":
            dotsDocked = (dict["on"] as? Bool) ?? false
        case "projectChats":
            if let items = dict["items"] as? [[String: Any]] { onProjectChats?(items) }
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
        hideKeyboardAccessoryBar()
        lockZoom()
        hasLoadedOnce = true
        loadError = false
        if pendingReloading {
            // un momentito pa' que chat.js ponga las burbujas antes de destapar
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                if pendingReloading { cancelPendingNewChat() }
            }
        }
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
        if pendingReloading { cancelPendingNewChat() }
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


// MARK: - Teclado estilo iMessage
// La WebView no se encoge con el teclado: el historial pasa por detrás de él (que es translúcido)
// y chat.js sube la caja de escribir justo encima del teclado.
extension WebModel {
    func watchKeyboard() {
        let nc = NotificationCenter.default
        keyboardTokens.append(nc.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main) { [weak self] n in
            let end = (n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect) ?? .zero
            let dur = (n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
            Task { @MainActor in self?.keyboardChanged(end: end, duration: dur) }
        })
        keyboardTokens.append(nc.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { [weak self] n in
            let dur = (n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
            Task { @MainActor in self?.sendKeyboard(0, duration: dur) }
        })
        // WebKit intenta mover toda la página pa' arriba al enfocar la caja; la dejamos quieta.
        // 0.3.21: también al cerrarse el teclado (ahí la página se iba pa' abajo y volvía). Se corrige en el mismo
        // instante (sin esperar otro ciclo) y solo cuando no es el dedo: el rebote al arrastrar sigue igual.
        zoomObservation = webView.scrollView.observe(\.zoomScale, options: [.new]) { [weak self] sv, _ in
            MainActor.assumeIsolated {
                if abs(sv.zoomScale - 1) > 0.001 { self?.lockZoom() }
            }
        }
        offsetObservation = webView.scrollView.observe(\.contentOffset, options: [.new]) { [weak self] sv, _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if abs(sv.zoomScale - 1) > 0.001 { self.lockZoom(); return }
                if sv.contentOffset.x != 0 && sv.zoomScale <= 1.001 { sv.contentOffset.x = 0 }
                guard self.keyboardUp || Date() < self.keyboardLockUntil,
                      sv.contentOffset.y != 0, !sv.isTracking, !sv.isDragging else { return }
                sv.setContentOffset(CGPoint(x: sv.contentOffset.x, y: 0), animated: false)
            }
        }
    }

    static let noZoomJS = """
    (function(){
      var C='width=device-width,initial-scale=1,maximum-scale=1,minimum-scale=1,user-scalable=no,viewport-fit=cover';
      function fix(){
        var h=document.head; if(!h) return;
        var m=h.querySelector('meta[name=viewport]');
        if(!m){ m=document.createElement('meta'); m.name='viewport'; h.appendChild(m); }
        if(m.content!==C) m.content=C;
      }
      fix();
      new MutationObserver(fix).observe(document.documentElement,{childList:true,subtree:true,attributes:true,attributeFilter:['content']});
      document.addEventListener('touchmove',function(e){ if(e.touches&&e.touches.length>1) e.preventDefault(); },{passive:false,capture:true});
      document.addEventListener('gesturestart',function(e){e.preventDefault();},{passive:false});
      document.addEventListener('gesturechange',function(e){e.preventDefault();},{passive:false});
    })();
    """

    /// WebKit a veces vuelve a crear/activar el pellizco al cargar; lo apagamos otra vez y regresamos a escala 1.
    func lockZoom() {
        let sv = webView.scrollView
        sv.pinchGestureRecognizer?.isEnabled = false
        sv.minimumZoomScale = 1
        sv.maximumZoomScale = 1
        // 0.7.5: WebKit tiene otros pellizcos en su vista de contenido; se apagan todos
        for v in [sv] + sv.subviews {
            for g in v.gestureRecognizers ?? [] where g is UIPinchGestureRecognizer { g.isEnabled = false }
        }
        sv.bouncesZoom = false
        if abs(sv.zoomScale - 1) > 0.001 { sv.setZoomScale(1, animated: false) }
        if sv.contentOffset.x != 0 { sv.setContentOffset(CGPoint(x: 0, y: sv.contentOffset.y), animated: false) }
    }

    private func keyboardChanged(end: CGRect, duration: Double) {
        guard let window = webView.window else { return }
        let frame = webView.convert(webView.bounds, to: window)
        let overlap = max(0, frame.maxY - end.minY)
        sendKeyboard(end.minY >= window.bounds.maxY ? 0 : overlap, duration: duration)
    }

    private func sendKeyboard(_ height: CGFloat, duration: Double) {
        keyboardUp = height > 0
        keyboardLockUntil = Date().addingTimeInterval(max(duration, 0.25) + 0.8)
        if keyboardUp { webView.scrollView.setContentOffset(.zero, animated: false) }
        // Con zoom (iPad) la página mide en píxeles CSS, no en puntos.
        let css = height / max(webView.pageZoom, 0.1)
        webView.evaluateJavaScript("window.pockitKeyboard && window.pockitKeyboard(\(Int(css)), \(duration))", completionHandler: nil)
    }

    /// iPad / Mac / iPhone acostado: claude.ai cambia a su diseño de computadora (con su barra lateral) cuando la
    /// página mide 768 px o más. Se agranda la página con zoom y se limita el ancho pa' que siempre vea el diseño
    /// de teléfono, que es el que tiene nuestro skin.
    func setZoom(_ z: CGFloat) {
        guard abs(webView.pageZoom - z) > 0.01 else { return }
        webView.pageZoom = z
    }
}


// MARK: - Sin la barra de flechitas / "Listo" encima del teclado (como en iMessage)
extension WebModel {
    /// WKWebView pone una barra (anterior / siguiente / Listo) encima del teclado. Se quita cambiando la clase de su
    /// vista de contenido por una subclase cuyo inputAccessoryView es nil. Si algo falla, simplemente queda la barra.
    func hideKeyboardAccessoryBar() {
        guard let content = webView.scrollView.subviews.first(where: { String(describing: type(of: $0)).hasPrefix("WKContent") }),
              let baseClass = object_getClass(content) else { return }
        let baseName = String(cString: class_getName(baseClass))
        if baseName.hasSuffix("_PockitNoBar") { return }
        let newName = baseName + "_PockitNoBar"
        var newClass: AnyClass? = NSClassFromString(newName)
        if newClass == nil {
            guard let made = objc_allocateClassPair(baseClass, newName, 0) else { return }
            let block: @convention(block) (AnyObject) -> UIView? = { _ in nil }
            let imp = imp_implementationWithBlock(block)
            let sel = #selector(getter: UIResponder.inputAccessoryView)
            class_addMethod(made, sel, imp, "@@:")
            objc_registerClassPair(made)
            newClass = made
        }
        if let newClass { object_setClass(content, newClass) }
    }
}
