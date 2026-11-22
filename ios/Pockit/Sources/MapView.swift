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
    var onLongPress: ((Double, Double, String?, String?) -> Void)?
    var onPinTap: ((UUID) -> Void)?
    var onPlaceTap: ((GamePlace) -> Void)?
    private var started = false
    private var pendingPins: String = "[]"
    private var pendingPlaces: String = "[]"

    override init() {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()
        cfg.applicationNameForUserAgent = "Version/18.0 Mobile/15E148 Safari/604.1"
        WebPerf.unlock120(cfg.preferences)
        let ucc = WKUserContentController()
        if let url = Bundle.main.url(forResource: "gtab-bridge", withExtension: "js"), let js = try? String(contentsOf: url, encoding: .utf8) {
            ucc.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
        cfg.userContentController = ucc
        webView = WKWebView(frame: .zero, configuration: cfg)
        super.init()
        ucc.add(self, name: "pockitMap")
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0x2F/255, green: 0x90/255, blue: 0xB0/255, alpha: 1)
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsLinkPreview = false
    }

    func start() {
        guard !started else { return }
        started = true
        failed = false
        webView.load(URLRequest(url: Self.url))
    }
    func reload() { ready = false; failed = false; webView.load(URLRequest(url: Self.url)) }

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
            webView.evaluateJavaScript("window.pkSetPins && window.pkSetPins(\(pendingPins))")
            webView.evaluateJavaScript("window.pkSetPlaces && window.pkSetPlaces(\(pendingPlaces))")
        case "error":
            failed = true
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
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failed = true }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { failed = true }
}

struct MapWebContainer: UIViewRepresentable {
    let web: WKWebView
    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = web.backgroundColor
        return v
    }
    func updateUIView(_ v: UIView, context: Context) {
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
    @State private var tappedPlace: GamePlace?

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
                if map.ready && store.data.pins.filter({ $0.space == "gtab" }).isEmpty {
                    Text(t.s("Mantené presionado en el mapa pa' poner un pin", "Long-press the map to drop a pin"))
                        .font(Theme.text(13, .medium)).foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(.ultraThinMaterial))
                        .padding(.bottom, 100)
                }
            }
            .navigationTitle(t.s("MAPA", "MAP"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showList = true } label: { Image(systemName: "list.bullet") }
                        .accessibilityLabel(t.s("Lista de pines", "Pin list"))
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showPlaces = true } label: { Image(systemName: "mappin.and.ellipse") }
                        .accessibilityLabel(t.s("Lugares del juego", "Game places"))
                }
            }
            .onAppear {
                map.start()
                map.onLongPress = { lat, lng, place, county in
                    var p = MapPin(x: lng, y: lat, name: "", kind: (filter ?? .pin).rawValue)
                    p.note = ""
                    editingNear = (place, county)
                    editing = p
                }
                map.onPlaceTap = { p in tappedPlace = p }
                map.onPinTap = { id in
                    if let p = store.data.pins.first(where: { $0.id == id }) { editingNear = (nil, nil); editing = p }
                }
                pushPins()
            }
            .onChange(of: store.data.pins) { _, _ in pushPins() }
            .onChange(of: store.data.places) { _, _ in map.setPlaces(store.data.places) }
            .onChange(of: filter) { _, _ in pushPins() }
            .onChange(of: map.ready) { _, _ in pushPins() }
            .sheet(item: $editing) { pin in
                PinSheet(pin: pin, place: editingNear.0, county: editingNear.1) { editing = nil }
                    .environmentObject(settings).environmentObject(store).environmentObject(state).environmentObject(web)
                    .presentationDetents([.medium, .large])
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

struct PlaceSearchSheet: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PockitStore
    let open: (String) -> Void
    @State private var query = ""
    @State private var results: [GamePlace] = []

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
