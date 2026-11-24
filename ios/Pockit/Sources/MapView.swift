import SwiftUI
import UIKit
import WebKit

// MARK: - Mapa
// El mapa es la página de GTABase (gtabase.com/gta-6/map) abierta dentro de la app, como en un navegador,
// pero mostrando solo el mapa: sin sus pines, menús ni el resto de la página. No se copia ni se guarda nada
// de su mapa en la app ni en el repo. Encima van los pines de Pockit.

enum PinKind: String, CaseIterable, Identifiable {
    case pin, secreto, coleccionable, foto, negocio
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .pin: return "mappin.circle.fill"
        case .secreto: return "questionmark.circle.fill"
        case .coleccionable: return "star.circle.fill"
        case .foto: return "camera.circle.fill"
        case .negocio: return "dollarsign.circle.fill"
        }
    }
    var emoji: String {
        switch self {
        case .pin: return "📍"
        case .secreto: return "❓"
        case .coleccionable: return "⭐️"
        case .foto: return "📸"
        case .negocio: return "💵"
        }
    }
    var color: UIColor {
        switch self {
        case .pin: return UIColor(Theme.pink)
        case .secreto: return UIColor(Theme.teal)
        case .coleccionable: return UIColor(Theme.sunset)
        case .foto: return UIColor(Theme.switchPink)
        case .negocio: return UIColor(Theme.coral)
        }
    }
    var hex: String {
        switch self {
        case .pin: return "#FF3E8A"
        case .secreto: return "#2EC4B6"
        case .coleccionable: return "#FFB547"
        case .foto: return "#CB84F8"
        case .negocio: return "#FF7A45"
        }
    }
    func title(_ t: L10n) -> String {
        switch self {
        case .pin: return t.s("Lugar", "Place")
        case .secreto: return t.s("Secreto", "Secret")
        case .coleccionable: return t.s("Coleccionable", "Collectible")
        case .foto: return t.s("Foto / vista", "Photo spot")
        case .negocio: return t.s("Negocio / dinero", "Business / money")
        }
    }
}


/// Una sola WebView pal mapa, que se queda viva aunque cambiés de pestaña (no recarga cada vez).
@MainActor
final class MapWeb: NSObject, ObservableObject, WKScriptMessageHandler, WKNavigationDelegate {
    static let shared = MapWeb()
    static let url = URL(string: "https://www.gtabase.com/gta-6/map/")!

    let webView: WKWebView
    @Published var ready = false
    @Published var failed = false
    /// true cuando está mostrando el mapa guardado (sin internet)
    @Published var offlineMode = false
    var onLongPress: ((Double, Double, String?, String?) -> Void)?
    var onPinTap: ((UUID) -> Void)?
    var onPlaceTap: ((GamePlace) -> Void)?
    private var started = false
    private var pendingPins: String = "[]"
    private var pendingPlaces: String = "[]"
    private var pendingCats: String = "[]"

    override init() {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()
        cfg.applicationNameForUserAgent = "Version/18.0 Mobile/15E148 Safari/604.1"
        cfg.setURLSchemeHandler(OfflineSchemeHandler(), forURLScheme: "pkoffline")
        WebPerf.unlock120(cfg.preferences)
        let ucc = WKUserContentController()
        if let url = Bundle.main.url(forResource: "gtab-bridge", withExtension: "js"), let js = try? String(contentsOf: url, encoding: .utf8) {
            ucc.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
        cfg.userContentController = ucc
        // Tamaño de pantalla desde el principio: así el mapa se arma bien aunque cargue por detrás.
        webView = WKWebView(frame: UIScreen.main.bounds, configuration: cfg)
        super.init()
        ucc.add(self, name: "pockitMap")
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0x2F/255, green: 0x90/255, blue: 0xB0/255, alpha: 1)
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.contentInset = .zero
        webView.allowsLinkPreview = false
    }

    func start() {
        guard !started else { return }
        started = true
        failed = false
        webView.load(URLRequest(url: Self.url))
    }

    /// Sin internet: se abre el mapa guardado en el teléfono (o, si no hay, lo que quedó en caché).
    private var triedCache = false
    private func loadFromCache() {
        if !offlineMode, OfflineMap.shared.hasSnapshot, let u = URL(string: "pkoffline://app/offline-map.html") {
            offlineMode = true
            ready = false
            webView.load(URLRequest(url: u))
            return
        }
        guard !triedCache, !offlineMode else { failed = true; return }
        triedCache = true
        webView.load(URLRequest(url: Self.url, cachePolicy: .returnCacheDataDontLoad))
    }
    func reload() { ready = false; failed = false; triedCache = false; offlineMode = false; webView.load(URLRequest(url: Self.url)) }

    func setPins(_ pins: [MapPin]) {
        let arr: [[String: Any]] = pins.map { p in
            let k = PinKind(rawValue: p.kind) ?? .pin
            return ["id": p.id.uuidString, "lat": p.y, "lng": p.x, "emoji": k.emoji, "color": k.hex, "done": p.done]
        }
        let json = String(data: (try? JSONSerialization.data(withJSONObject: arr)) ?? Data("[]".utf8), encoding: .utf8) ?? "[]"
        pendingPins = json
        if ready { webView.evaluateJavaScript("window.pkSetPins && window.pkSetPins(\(json))") }
    }

    func setPlaces(_ names: [String]) {
        let json = String(data: (try? JSONSerialization.data(withJSONObject: names)) ?? Data("[]".utf8), encoding: .utf8) ?? "[]"
        pendingPlaces = json
        if ready { webView.evaluateJavaScript("window.pkSetPlaces && window.pkSetPlaces(\(json))") }
    }

    func setPlaceCats(_ ids: [String]) {
        let json = String(data: (try? JSONSerialization.data(withJSONObject: ids)) ?? Data("[]".utf8), encoding: .utf8) ?? "[]"
        pendingCats = json
        if ready { webView.evaluateJavaScript("window.pkSetPlaceCats && window.pkSetPlaceCats(\(json))") }
    }

    struct ZoneCat: Hashable { let cat: String; let found: Int; let total: Int }
    struct ZoneInfo: Identifiable { let id = UUID(); let name: String; let level: String; let found: Int; let total: Int; let byCat: [ZoneCat] }
    var onZoneTap: ((ZoneInfo) -> Void)?
    private var pendingZones: String?

    /// Coleccionables por zona: manda al mapa las zonas (del mapa guardado), qué categorías cuentan y cuáles ya tenés.
    func setZones(on: Bool, collectibles: [CollectibleCategory]) {
        Task { @MainActor in
            let cats = await categories().filter { $0.isCollectible }
            struct L: Codable { let kind: String; let sub: String?; let t: String; let lat: Double; let lng: Double }
            struct S: Codable { let labels: [L]? }
            let labels = (try? JSONDecoder().decode(S.self, from: Data(contentsOf: OfflineMap.shared.snapshotURL)))?.labels ?? []
            func norm(_ s: String) -> String {
                var x = s.lowercased().folding(options: .diacriticInsensitive, locale: nil).filter { $0.isLetter || $0.isNumber }
                if x.hasSuffix("s") { x.removeLast() }
                return x
            }
            var found: [String: [String]] = [:]
            for c in cats {
                let cn = norm(c.name)
                let mine = collectibles.filter { let m = norm($0.name); return m == cn || (m.count > 4 && (m.contains(cn) || cn.contains(m))) }
                let names = mine.flatMap { $0.items.map(\.name) }
                if !names.isEmpty { found[c.id] = names }
            }
            let cfg: [String: Any] = [
                "on": on,
                "labels": labels.map { ["kind": $0.kind, "sub": $0.sub ?? "", "t": $0.t, "lat": $0.lat, "lng": $0.lng] },
                "cats": cats.map { ["id": $0.id, "name": $0.name] },
                "found": found,
            ]
            guard let d = try? JSONSerialization.data(withJSONObject: cfg), let json = String(data: d, encoding: .utf8) else { return }
            pendingZones = json
            if ready { _ = try? await webView.evaluateJavaScript("window.pkSetZones && window.pkSetZones(\(json))") }
        }
    }

    private var pendingRoute: String?
    func setRoute(_ stops: [String]) {
        let json = String(data: (try? JSONSerialization.data(withJSONObject: stops)) ?? Data("[]".utf8), encoding: .utf8) ?? "[]"
        pendingRoute = json
        if ready { webView.evaluateJavaScript("window.pkSetRoute && window.pkSetRoute(\(json))") }
    }
    func fitRoute() { webView.evaluateJavaScript("window.pkFitRoute && window.pkFitRoute()") }

    func categories() async -> [PlaceCategory] {
        guard ready else { return [] }
        let r = try? await webView.callAsyncJavaScript("return JSON.stringify(window.pkCategories ? window.pkCategories() : [])", arguments: [:], contentWorld: .page)
        guard let str = r as? String, let d = str.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: d) as? [[String: Any]] else { return [] }
        return arr.compactMap { o in
            guard let id = o["id"] as? String else { return nil }
            return PlaceCategory(id: id, name: o["name"] as? String ?? id, group: o["group"] as? String ?? "", count: o["count"] as? Int ?? 0)
        }
    }

    func search(_ q: String) async -> [GamePlace] {
        guard ready else { return [] }
        let r = try? await webView.callAsyncJavaScript("return JSON.stringify(window.pkSearch ? window.pkSearch(q) : [])", arguments: ["q": q], contentWorld: .page)
        guard let str = r as? String, let d = str.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: d) as? [[String: Any]] else { return [] }
        return arr.compactMap { o in (o["name"] as? String).map { GamePlace(name: $0, category: o["cat"] as? String ?? "") } }
    }

    func focusPlace(_ name: String) {
        _ = webView.callAsyncJavaScript("return window.pkFocusPlace && window.pkFocusPlace(n)", arguments: ["n": name], in: nil, in: .page) { _ in }
    }

    func flyTo(_ p: MapPin) { webView.evaluateJavaScript("window.pkFlyTo && window.pkFlyTo(\(p.y), \(p.x))") }

    /// Centra el punto, espera a que carguen los cuadritos del mapa y le toma foto (pa' mandársela a Marisol).
    func snapshot(lat: Double, lng: Double) async -> (Data?, String?, String?) {
        let view = try? await webView.evaluateJavaScript("JSON.stringify(window.pkView ? window.pkView() : null)") as? String
        let near = try? await webView.callAsyncJavaScript("return JSON.stringify(await window.pkFocusWait(lat, lng, 4))",
                                                         arguments: ["lat": lat, "lng": lng], contentWorld: .page) as? String
        try? await Task.sleep(for: .milliseconds(150))
        let img = try? await webView.takeSnapshot(configuration: WKSnapshotConfiguration())
        if let view, let d = view.data(using: .utf8), let v = try? JSONSerialization.jsonObject(with: d) as? [String: Double],
           let la = v["lat"], let ln = v["lng"], let z = v["zoom"] {
            _ = try? await webView.evaluateJavaScript("window.pkSetView(\(la), \(ln), \(z))")
        }
        var place: String?, county: String?
        if let near, let d = near.data(using: .utf8), let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
            place = o["place"] as? String; county = o["county"] as? String
        }
        return (img?.jpegData(compressionQuality: 0.82), place, county)
    }
    func snapshot(of p: MapPin) async -> (Data?, String?, String?) { await snapshot(lat: p.y, lng: p.x) }

    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
        guard let d = m.body as? [String: Any], let type = d["type"] as? String else { return }
        switch type {
        case "ready":
            ready = true
            failed = false
            // Con internet: se guarda/renueva la copia de lugares pa' usar sin internet
            if !offlineMode, !OfflineMap.shared.hasSnapshot || OfflineMap.shared.snapshotIsStale {
                webView.evaluateJavaScript("window.pkSnapshot && window.pkSnapshot()") { r, _ in
                    if let json = r as? String { Task { @MainActor in OfflineMap.shared.saveSnapshot(json) } }
                }
            }
            webView.evaluateJavaScript("window.pkSetPins && window.pkSetPins(\(pendingPins))")
            webView.evaluateJavaScript("window.pkSetPlaces && window.pkSetPlaces(\(pendingPlaces))")
            webView.evaluateJavaScript("window.pkSetPlaceCats && window.pkSetPlaceCats(\(pendingCats))")
            if let z = pendingZones { webView.evaluateJavaScript("window.pkSetZones && window.pkSetZones(\(z))") }
            if let r = pendingRoute { webView.evaluateJavaScript("window.pkSetRoute && window.pkSetRoute(\(r))") }
        case "error":
            if offlineMode { failed = true } else { loadFromCache() }
        case "longPress":
            let near = d["near"] as? [String: Any]
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onLongPress?(d["lat"] as? Double ?? 0, d["lng"] as? Double ?? 0, near?["place"] as? String, near?["county"] as? String)
        case "placeTap":
            let near = d["near"] as? [String: Any]
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onPlaceTap?(GamePlace(name: d["name"] as? String ?? "", category: d["cat"] as? String ?? "",
                                  lat: d["lat"] as? Double ?? 0, lng: d["lng"] as? Double ?? 0,
                                  place: near?["place"] as? String, county: near?["county"] as? String))
        case "zoneTap":
            let by = (d["byCat"] as? [[String: Any]] ?? []).map { ZoneCat(cat: $0["cat"] as? String ?? "", found: $0["found"] as? Int ?? 0, total: $0["total"] as? Int ?? 0) }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onZoneTap?(ZoneInfo(name: d["name"] as? String ?? "", level: d["level"] as? String ?? "", found: d["found"] as? Int ?? 0, total: d["total"] as? Int ?? 0, byCat: by))
        case "pinTap":
            if let s = d["id"] as? String, let id = UUID(uuidString: s) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onPinTap?(id)
            }
        default: break
        }
    }

    // Solo el mapa: cualquier otro enlace (anuncios, menús) no navega.
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard action.targetFrame?.isMainFrame ?? false else { return .allow }
        if let u = action.request.url, u.host?.hasSuffix("gtabase.com") == true, u.path.hasPrefix("/gta-6/map") { return .allow }
        return action.navigationType == .other ? .allow : .cancel
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { if !ready { loadFromCache() } }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { loadFromCache() }
}

struct MapWebContainer: UIViewRepresentable {
    let web: WKWebView
    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = web.backgroundColor
        return v
    }
    func updateUIView(_ v: UIView, context: Context) {
        // que Leaflet vuelva a medir cuando cambia el tamaño (si no, abajo quedaba una franja sin mapa)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { web.evaluateJavaScript("window.pkFit && window.pkFit()") }
        if web.superview !== v {
            web.removeFromSuperview()
            web.translatesAutoresizingMaskIntoConstraints = false
            v.addSubview(web)
            NSLayoutConstraint.activate([
                web.leadingAnchor.constraint(equalTo: v.leadingAnchor), web.trailingAnchor.constraint(equalTo: v.trailingAnchor),
                web.topAnchor.constraint(equalTo: v.topAnchor), web.bottomAnchor.constraint(equalTo: v.bottomAnchor)
            ])
        }
    }
}

struct MapaView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PockitStore
    @EnvironmentObject private var state: PockitState
    @EnvironmentObject private var web: WebModel
    @ObservedObject private var map = MapWeb.shared

    @State private var editing: MapPin?
    @State private var editingNear: (String?, String?) = (nil, nil)
    @State private var filter: PinKind?
    @State private var showList = false
    @State private var showPlaces = false
    @State private var showOffline = false
    @State private var showHint = false
    @State private var tappedPlace: GamePlace?
    @AppStorage("pk.zones.on") private var zonesOn = false
    @State private var tappedZone: MapWeb.ZoneInfo?

    var body: some View {
        let t = settings.t
        NavigationStack {
            ZStack {
                MapWebContainer(web: map.webView)
                    .ignoresSafeArea(edges: .bottom)
                if !map.ready {
                    VStack(spacing: 12) {
                        if map.failed {
                            Image(systemName: "wifi.exclamationmark").font(.system(size: 34)).foregroundStyle(.white)
                            Text(t.s("No pude abrir el mapa. ¿Tenés internet?", "Couldn't open the map. Are you online?"))
                                .font(Theme.text(15)).foregroundStyle(.white)
                            Button(t.s("Reintentar", "Retry")) { map.reload() }.buttonStyle(.borderedProminent)
                        } else {
                            ProgressView().tint(.white)
                            Text(t.s("Abriendo el mapa de Leonida…", "Opening the Leonida map…")).font(Theme.text(14)).foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(red: 0x2F/255, green: 0x90/255, blue: 0xB0/255))
                }
            }
            .overlay(alignment: .top) { if map.ready { filterBar(t) } }
            .overlay(alignment: .bottom) {
                if map.ready && showHint {
                    Text(t.s("Mantené presionado en el mapa pa' poner un pin", "Long-press the map to drop a pin"))
                        .font(Theme.text(13, .medium)).foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(.ultraThinMaterial))
                        .padding(.bottom, 100)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.8), value: showHint)
            .task(id: map.ready) {
                // el aviso sale solo 6 segundos al entrar al mapa
                guard map.ready else { return }
                showHint = true
                try? await Task.sleep(for: .seconds(6))
                showHint = false
            }
            .onDisappear { showHint = false }
            .navigationTitle(t.s("MAPA", "MAP"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showList = true } label: { Image(systemName: "list.bullet") }
                        .accessibilityLabel(t.s("Lista de pines", "Pin list"))
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { zonesOn.toggle(); UISelectionFeedbackGenerator().selectionChanged() } label: {
                        Image(systemName: zonesOn ? "square.grid.3x3.fill" : "square.grid.3x3")
                    }
                    .accessibilityLabel(t.s("Coleccionables por zona", "Collectibles by zone"))
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showPlaces = true } label: { Image(systemName: "mappin.and.ellipse") }
                        .accessibilityLabel(t.s("Lugares del juego", "Game places"))
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showOffline = true } label: { Image(systemName: map.offlineMode ? "wifi.slash" : (OfflineMap.shared.completedLevel != nil ? "checkmark.icloud" : "arrow.down.circle")) }
                        .accessibilityLabel(t.s("Mapa sin internet", "Offline map"))
                }
            }
            .onAppear {
                map.start()
                // si estaba en el mapa guardado, se prueba otra vez con internet
                if map.offlineMode { map.reload() }
                map.onLongPress = { lat, lng, place, county in
                    var p = MapPin(x: lng, y: lat, name: "", kind: (filter ?? .pin).rawValue)
                    p.note = ""
                    editingNear = (place, county)
                    editing = p
                }
                map.onPlaceTap = { p in tappedPlace = p }
                map.onZoneTap = { z in tappedZone = z }
                map.setZones(on: zonesOn, collectibles: store.data.collectibles)
                map.setRoute(store.data.route?.stops ?? [])
                map.onPinTap = { id in
                    if let p = store.data.pins.first(where: { $0.id == id }) { editingNear = (nil, nil); editing = p }
                }
                pushPins()
            }
            .onChange(of: store.data.pins) { _, _ in pushPins() }
            .onChange(of: store.data.places) { _, _ in map.setPlaces(store.data.places) }
            .onChange(of: store.data.placeCats) { _, _ in map.setPlaceCats(store.data.placeCats) }
            .onChange(of: zonesOn) { _, on in map.setZones(on: on, collectibles: store.data.collectibles) }
            .onChange(of: store.data.route) { _, r in map.setRoute(r?.stops ?? []); if r != nil { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { map.fitRoute() } } }
            .overlay(alignment: .bottom) {
                if let r = store.data.route {
                    HStack(spacing: 10) {
                        Button { map.fitRoute() } label: {
                            HStack(spacing: 8) {
                                Text("🛣️")
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(r.title).font(Theme.text(14, .semibold)).foregroundStyle(.white).lineLimit(1)
                                    Text("\(r.stops.count) \(t.s("paradas", "stops"))").font(Theme.text(11)).foregroundStyle(Theme.lilac)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        Button { store.clearRoute() } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 20)).foregroundStyle(Theme.lilac) }
                            .accessibilityLabel(t.s("Quitar ruta", "Clear route"))
                    }
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Capsule().fill(.ultraThinMaterial))
                    .background(Capsule().fill(Theme.nightDeep.opacity(0.55)))
                    .overlay(Capsule().stroke(Theme.switchPink.opacity(0.6), lineWidth: 1.2))
                    .padding(.bottom, 14)
                }
            }
            .onChange(of: store.data.collectibles) { _, c in if zonesOn { map.setZones(on: true, collectibles: c) } }
            .onChange(of: map.ready) { _, r in if r { map.setZones(on: zonesOn, collectibles: store.data.collectibles) } }
            .sheet(item: $tappedZone) { z in
                ZoneSheet(zone: z).environmentObject(settings).presentationDetents([.medium, .large])
            }
            .onChange(of: filter) { _, _ in pushPins() }
            .onChange(of: map.ready) { _, _ in pushPins() }
            .sheet(item: $editing) { pin in
                PinSheet(pin: pin, place: editingNear.0, county: editingNear.1) { editing = nil }
                    .environmentObject(settings).environmentObject(store).environmentObject(state).environmentObject(web)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showOffline) {
                OfflineMapSheet().environmentObject(settings).presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showPlaces) {
                PlaceSearchSheet { name in showPlaces = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { map.focusPlace(name) } }
                    .environmentObject(settings).environmentObject(store)
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $tappedPlace) { p in
                PlaceSheet(place: p) { tappedPlace = nil }
                    .environmentObject(settings).environmentObject(store).environmentObject(state).environmentObject(web)
                    .presentationDetents([.height(320), .medium])
            }
            .sheet(isPresented: $showList) {
                PinListSheet { pin in
                    showList = false
                    map.flyTo(pin)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { editingNear = (nil, nil); editing = pin }
                }
                .environmentObject(settings).environmentObject(store)
                .presentationDetents([.medium, .large])
            }
        }
    }

    private func pushPins() {
        map.setPlaces(store.data.places)
        map.setPlaceCats(store.data.placeCats)
        map.setPins(store.data.pins.filter { $0.space == "gtab" && (filter == nil || $0.kind == filter!.rawValue) })
    }

    private func filterBar(_ t: L10n) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(t.s("Todos", "All"), on: filter == nil) { filter = nil }
                ForEach(PinKind.allCases) { k in
                    chip(k.title(t), emoji: k.emoji, on: filter == k) { filter = filter == k ? nil : k }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
    }

    private func chip(_ title: String, emoji: String? = nil, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let emoji { Text(emoji) }
                Text(title)
            }
            .font(Theme.text(13, .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12).frame(height: 32)
            .background(Capsule().fill(on ? Theme.purple : Theme.nightDeep.opacity(0.6)))
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(Capsule().stroke(on ? Theme.switchPink : Color.white.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Hoja de un pin
struct PinSheet: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PockitStore
    @EnvironmentObject private var state: PockitState
    @EnvironmentObject private var web: WebModel
    @State var pin: MapPin
    let place: String?
    let county: String?
    let close: () -> Void
    @State private var asking = false

    private var isNew: Bool { !store.data.pins.contains { $0.id == pin.id } }

    var body: some View {
        let t = settings.t
        NavigationStack {
            Form {
                Section {
                    TextField(t.s("Nombre (ej. muelle viejo)", "Name (e.g. the old pier)"), text: $pin.name)
                    TextField(t.s("Nota", "Note"), text: $pin.note, axis: .vertical).lineLimit(1...4)
                    Picker(t.s("Tipo", "Type"), selection: $pin.kind) {
                        ForEach(PinKind.allCases) { k in Text("\(k.emoji) \(k.title(t))").tag(k.rawValue) }
                    }
                    Toggle(t.s("Ya lo hice", "Done"), isOn: $pin.done)
                } footer: {
                    if let where_ = [place, county].compactMap({ $0 }).joined(separator: " · ").nilIfEmpty {
                        Text(t.s("Cerca de: ", "Near: ") + where_)
                    }
                }
                .listRowBackground(Theme.panel)

                Section {
                    Button { ask(hint: true) } label: { Label(t.s("Pista sin spoilers", "Spoiler-free hint"), systemImage: "sparkles") }
                    Button { ask(hint: false) } label: { Label(t.s("¿Qué hay por aquí?", "What's around here?"), systemImage: "binoculars.fill") }
                } footer: {
                    Text(t.s("Le mando a Marisol una foto del mapa con tu pin y la zona.", "Marisol gets a picture of the map with your pin and the area."))
                }
                .listRowBackground(Theme.panel)
                .disabled(asking)

                if !isNew {
                    Section {
                        Button(role: .destructive) { store.delete(pin); close() } label: { Label(t.s("Borrar pin", "Delete pin"), systemImage: "trash") }
                    }
                    .listRowBackground(Theme.panel)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.menu.ignoresSafeArea())
            .navigationTitle(isNew ? t.s("Nuevo pin", "New pin") : (pin.name.isEmpty ? "Pin" : pin.name))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(t.cancel) { close() } }
                ToolbarItem(placement: .confirmationAction) { Button(t.s("Guardar", "Save")) { save(); close() } }
            }
            .overlay { if asking { ProgressView().tint(.white).padding(20).background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial)) } }
        }
    }

    private func save() {
        if pin.name.trimmingCharacters(in: .whitespaces).isEmpty {
            pin.name = place ?? PinKind(rawValue: pin.kind)?.title(settings.t) ?? "Pin"
        }
        store.savePin(pin)
    }

    private func ask(hint: Bool) {
        let t = settings.t
        save()
        asking = true
        let p = pin
        Task {
            let (img, nearPlace, nearCounty) = await MapWeb.shared.snapshot(of: p)
            let zone = [nearPlace ?? place, nearCounty ?? county].compactMap { $0 }.joined(separator: ", ")
            let spot = p.name + (p.note.isEmpty ? "" : " — \(p.note)") + (zone.isEmpty ? "" : " (\(zone))")
            let kind = PinKind(rawValue: p.kind) ?? .pin
            let msg: String
            if hint {
                switch kind {
                case .secreto:
                    msg = t.s("📍 Mapa: ¿hay algún secreto cerca de este punto: \(spot)? Dame solo la Pista 1, sin spoilers. Te adjunto el mapa con mi pin.",
                              "📍 Map: is there a secret near this spot: \(spot)? Just Pista 1, no spoilers. Map with my pin attached.")
                case .coleccionable:
                    msg = t.s("📍 Mapa: ¿hay coleccionables cerca de este punto: \(spot)? Primero solo una pista, sin spoilers. Te adjunto el mapa con mi pin.",
                              "📍 Map: any collectibles near this spot: \(spot)? Just a hint first, no spoilers. Map with my pin attached.")
                default:
                    msg = t.s("📍 Mapa: dame una pista sin spoilers de algo que valga la pena cerca de este punto: \(spot). Te adjunto el mapa con mi pin.",
                              "📍 Map: give me a spoiler-free hint about something worth it near this spot: \(spot). Map with my pin attached.")
                }
            } else {
                msg = t.s("📍 Mapa: ¿qué hay por aquí: \(spot)? Actividades, negocios, vistas, lo que valga la pena, sin spoilers. Te adjunto el mapa con mi pin.",
                          "📍 Map: what's around here: \(spot)? Activities, businesses, views, anything worth it, no spoilers. Map with my pin attached.")
            }
            if let img {
                _ = await web.attach(data: img, name: "mapa-\(Int(Date().timeIntervalSince1970)).jpg", mime: "image/jpeg")
                try? await Task.sleep(for: .milliseconds(900))
            }
            state.tab = .marisol
            web.send(msg)
            asking = false
            close()
        }
    }
}


// MARK: - Lista de pines
struct PinListSheet: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PockitStore
    let open: (MapPin) -> Void
    @State private var query = ""

    var body: some View {
        let t = settings.t
        NavigationStack {
            List {
                ForEach(PinKind.allCases) { k in
                    let pins = store.data.pins.filter { $0.space == "gtab" && $0.kind == k.rawValue && (query.isEmpty || ($0.name + " " + $0.note).localizedCaseInsensitiveContains(query)) }
                    if !pins.isEmpty {
                        Section(k.title(t)) {
                            ForEach(pins) { p in
                                Button { open(p) } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: p.done ? "checkmark.circle.fill" : k.symbol).foregroundStyle(Color(k.color)).font(.system(size: 22))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(p.name).foregroundStyle(.white).strikethrough(p.done)
                                            if !p.note.isEmpty { Text(p.note).font(Theme.text(13)).foregroundStyle(Theme.lilac).lineLimit(1) }
                                        }
                                    }
                                }
                                .swipeActions { Button(role: .destructive) { store.delete(p) } label: { Label(t.s("Borrar", "Delete"), systemImage: "trash") } }
                            }
                        }
                        .listRowBackground(Theme.panel)
                    }
                }
                if store.data.pins.isEmpty {
                    Text(t.s("Todavía no hay pines.", "No pins yet.")).foregroundStyle(Theme.lilac).listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.menu.ignoresSafeArea())
            .searchable(text: $query, prompt: t.s("Buscar", "Search"))
            .navigationTitle(t.s("Pines", "Pins"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}


// MARK: - Lugares del juego (los del mapa de GTABase que ya desbloqueaste)
struct GamePlace: Identifiable, Hashable {
    var id: String { name }
    var name: String
    var category: String
    var lat: Double = 0
    var lng: Double = 0
    var place: String? = nil
    var county: String? = nil
}

struct PlaceCategory: Identifiable, Hashable {
    let id: String
    let name: String
    let group: String
    let count: Int
    /// Lo que cuenta en "coleccionables por zona".
    var isCollectible: Bool {
        let g = group.lowercased(), i = id.lowercased()
        return g.contains("collect") || i.hasPrefix("card-") || ["hidden-package", "treasure", "meteorite", "message-bottle", "magazine", "playlist",
                "waink-curiosity", "waink-landmark", "waink-sculpture", "meditation", "ahol-street-art", "mural", "luxury-watch"].contains(i)
    }
    /// Coleccionables y cosas escondidas: mostrarlas completas sería spoiler.
    var isSecret: Bool {
        let g = group.lowercased(), i = id.lowercased()
        return g.contains("collect") || i.hasPrefix("card-") || ["hidden-package", "treasure", "meteorite", "message-bottle", "magazine", "playlist",
                "waink-curiosity", "waink-landmark", "waink-sculpture", "meditation", "unique-weapon", "safe", "yellow-loot-box", "scoop-container",
                "random-event", "standout-vehicle", "under-the-bridge", "knife-flight", "stunt-jump", "ahol-street-art", "mural", "luxury-watch",
                "weapon-spawn", "vehicle-spawn"].contains(i)
    }
}

struct PlaceSearchSheet: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PockitStore
    let open: (String) -> Void
    @State private var query = ""
    @State private var results: [GamePlace] = []
    @State private var cats: [PlaceCategory] = []
    @State private var showSecretCats = false

    var body: some View {
        let t = settings.t
        NavigationStack {
            List {
                if query.count < 3 {
                    Section {
                        Text(t.s("Escribí el nombre de un lugar que ya desbloqueaste (ej. Chuck's Tackle) y tocá ＋ pa' ponerlo en tu mapa. Así solo ves lo que ya tenés, sin spoilers.",
                                 "Type a place you've already unlocked (e.g. Chuck's Tackle) and tap ＋ to add it to your map. You only see what you have, no spoilers."))
                            .font(Theme.text(14)).foregroundStyle(Theme.lilac)
                    }
                    .listRowBackground(Color.clear)
                    Section {
                        ForEach(cats.filter { showSecretCats || !$0.isSecret }) { c in
                            let on = store.data.placeCats.contains(c.id)
                            Button { store.togglePlaceCat(c.id); UISelectionFeedbackGenerator().selectionChanged() } label: {
                                HStack {
                                    Text(c.name).foregroundStyle(.white)
                                    if c.isSecret { Text("⚠️").font(.system(size: 12)) }
                                    Spacer()
                                    Text("\(c.count)").font(Theme.text(13)).foregroundStyle(Theme.lilac)
                                    Image(systemName: on ? "checkmark.circle.fill" : "circle").foregroundStyle(on ? Theme.teal : Theme.lilac.opacity(0.6))
                                }
                            }
                        }
                        Toggle(t.s("Mostrar también coleccionables y secretos (spoilers)", "Also show collectibles & secrets (spoilers)"), isOn: $showSecretCats)
                            .font(Theme.text(14))
                    } header: {
                        Text(t.s("Categorías completas", "Whole categories"))
                    } footer: {
                        Text(t.s("Tiendas, gasolineras, bancos y negocios casi siempre se ven en el mapa desde el principio: activalos de un toque.",
                                 "Shops, gas stations, banks and businesses usually show on the map from the start: turn them on in one tap."))
                    }
                    .listRowBackground(Theme.panel)
                    if !store.data.places.isEmpty {
                        Section(t.s("En tu mapa", "On your map")) {
                            ForEach(store.data.places, id: \.self) { n in
                                Button { open(n) } label: { Text(n).foregroundStyle(.white) }
                                    .swipeActions { Button(role: .destructive) { store.removePlace(n) } label: { Label(t.s("Quitar", "Remove"), systemImage: "minus.circle") } }
                            }
                        }
                        .listRowBackground(Theme.panel)
                    }
                } else {
                    ForEach(results) { r in
                        let have = store.data.places.contains { $0.caseInsensitiveCompare(r.name) == .orderedSame }
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.name).foregroundStyle(.white)
                                Text(r.category).font(Theme.text(12)).foregroundStyle(Theme.lilac)
                            }
                            Spacer()
                            Button {
                                if have { store.removePlace(r.name) } else { store.addPlace(r.name); UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                            } label: {
                                Image(systemName: have ? "checkmark.circle.fill" : "plus.circle.fill")
                                    .font(.system(size: 24)).foregroundStyle(have ? Theme.teal : Theme.switchPink)
                            }
                            .buttonStyle(.plain)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { if have { open(r.name) } }
                    }
                    .listRowBackground(Theme.panel)
                    if results.isEmpty {
                        Text(t.s("No encontré ese lugar.", "No place by that name.")).foregroundStyle(Theme.lilac).listRowBackground(Color.clear)
                    } else if results.count > 1 {
                        Button { store.addPlaces(results.map(\.name)); UIImpactFeedbackGenerator(style: .medium).impactOccurred() } label: {
                            Label(t.s("Agregar todos (\(results.count))", "Add all (\(results.count))"), systemImage: "plus.square.on.square")
                        }
                        .listRowBackground(Theme.panel)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.menu.ignoresSafeArea())
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: t.s("Buscar lugar", "Search place"))
            .navigationTitle(t.s("Lugares del juego", "Game places"))
            .navigationBarTitleDisplayMode(.inline)
            .task(id: query) {
                try? await Task.sleep(for: .milliseconds(200))
                results = await MapWeb.shared.search(query)
            }
            .task { cats = await MapWeb.shared.categories() }
        }
    }
}

struct PlaceSheet: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PockitStore
    @EnvironmentObject private var state: PockitState
    @EnvironmentObject private var web: WebModel
    let place: GamePlace
    let close: () -> Void
    @State private var asking = false

    var body: some View {
        let t = settings.t
        NavigationStack {
            Form {
                Section {
                    Text(place.category).foregroundStyle(Theme.lilac)
                    let zone = [place.place, place.county].compactMap { $0 }.joined(separator: " · ")
                    if !zone.isEmpty { Text(zone).foregroundStyle(Theme.lilac) }
                }
                .listRowBackground(Theme.panel)
                Section {
                    Button { ask() } label: { Label(t.s("Preguntarle a Marisol", "Ask Marisol"), systemImage: "bubble.left.fill") }
                    Button(role: .destructive) { store.removePlace(place.name); close() } label: { Label(t.s("Quitar de mi mapa", "Remove from my map"), systemImage: "minus.circle") }
                }
                .listRowBackground(Theme.panel)
                .disabled(asking)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.menu.ignoresSafeArea())
            .navigationTitle(place.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("OK") { close() } } }
            .overlay { if asking { ProgressView().tint(.white).padding(20).background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial)) } }
        }
    }

    private func ask() {
        let t = settings.t
        asking = true
        Task {
            let (img, _, _) = await MapWeb.shared.snapshot(lat: place.lat, lng: place.lng)
            let zone = [place.place, place.county].compactMap { $0 }.joined(separator: ", ")
            let msg = t.s("📍 Mapa: estoy viendo \(place.name) (\(place.category)\(zone.isEmpty ? "" : ", \(zone)")). ¿Qué vale la pena aquí y alrededor? Sin spoilers.",
                          "📍 Map: I'm looking at \(place.name) (\(place.category)\(zone.isEmpty ? "" : ", \(zone)")). What's worth it here and around? No spoilers.")
            if let img {
                _ = await web.attach(data: img, name: "mapa-\(Int(Date().timeIntervalSince1970)).jpg", mime: "image/jpeg")
                try? await Task.sleep(for: .milliseconds(900))
            }
            state.tab = .marisol
            web.send(msg)
            asking = false
            close()
        }
    }
}


/// Detalle de una zona: cuántos coleccionables llevás de cada tipo (solo números, sin ubicaciones).
struct ZoneSheet: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    let zone: MapWeb.ZoneInfo
    var body: some View {
        let t = settings.t
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text(t.s("Total", "Total")).font(Theme.text(16, .semibold)).foregroundStyle(.white)
                        Spacer()
                        Text("\(zone.found) / \(zone.total)").font(Theme.display(22)).foregroundStyle(zone.found >= zone.total && zone.total > 0 ? Color(red: 0.18, green: 0.9, blue: 0.66) : Theme.switchPink)
                    }
                    .menuRow()
                }
                Section {
                    ForEach(zone.byCat, id: \.self) { c in
                        HStack {
                            Text(c.cat).font(Theme.text(15)).foregroundStyle(.white)
                            Spacer()
                            Text("\(c.found) / \(c.total)").font(Theme.text(15, .semibold)).foregroundStyle(c.found >= c.total ? Color(red: 0.18, green: 0.9, blue: 0.66) : Theme.lilac)
                        }
                        .menuRow()
                    }
                } footer: {
                    Text(t.s("Cuentan los que anotaste con su nombre. Los que guardaste solo como número no se pueden ubicar en una zona.",
                             "Only collectibles saved by name count here. Ones saved just as a number can't be placed in a zone."))
                        .font(Theme.text(12, relativeTo: .caption)).foregroundStyle(Theme.lilac.opacity(0.85))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.menu.ignoresSafeArea())
            .navigationTitle(zone.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() } } }
        }
    }
}
