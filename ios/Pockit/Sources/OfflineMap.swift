import Foundation
import WebKit
import SwiftUI

/// Mapa de Leonida guardado en el teléfono pa' usarlo sin internet.
/// Todo queda en Application Support/OfflineMap (nunca en el repo):
///  - snapshot.json: lugares, categorías, íconos y nombres de zonas (se renueva solo cuando abrís el mapa con internet)
///  - tiles/: las imágenes del mapa por nivel de zoom (se bajan cuando vos lo pedís)
///  - icons/: los íconos de cada categoría
@MainActor
final class OfflineMap: ObservableObject {
    static let shared = OfflineMap()
    static let site = "https://www.gtabase.com"

    enum Level: Int, CaseIterable, Identifiable {
        case light = 3, normal = 4, max = 5
        var id: Int { rawValue }
        func title(_ t: L10n) -> String {
            switch self {
            case .light: return t.s("Ligero", "Light")
            case .normal: return t.s("Normal", "Normal")
            case .max: return t.s("Máximo detalle", "Max detail")
            }
        }
        func blurb(_ t: L10n) -> String {
            switch self {
            case .light: return t.s("Todo el mapa, zoom medio", "Whole map, medium zoom")
            case .normal: return t.s("Se leen calles y zonas", "Streets and areas readable")
            case .max: return t.s("Igual que con internet", "Same as online")
            }
        }
    }

    @Published var hasSnapshot = false
    @Published var snapshotDate: Date?
    @Published var downloading = false
    @Published var done = 0
    @Published var total = 0
    @Published var tilesOnDisk = 0
    @Published var bytesOnDisk: Int64 = 0
    @Published var savedLevel: Int? = UserDefaults.standard.object(forKey: "pockit.offline.level") as? Int
    @Published var lastError: String?
    /// Nivel que terminó de bajarse completo (sin cortes).
    @Published var completedLevel: Int? = UserDefaults.standard.object(forKey: "pockit.offline.completed") as? Int
    private var task: Task<Void, Never>?

    let root: URL
    var snapshotURL: URL { root.appendingPathComponent("snapshot.json") }
    var tilesDir: URL { root.appendingPathComponent("tiles", isDirectory: true) }
    var iconsDir: URL { root.appendingPathComponent("icons", isDirectory: true) }

    init() {
        root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("OfflineMap", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var r = root
        var rv = URLResourceValues(); rv.isExcludedFromBackup = true
        try? r.setResourceValues(rv)
        refreshInfo()
        // 0.6.1: las descargas hechas con la 0.6.0 no quedaban marcadas como completas
        if completedLevel == nil, let lv = savedLevel, tilesOnDisk > plan(upTo: lv).count / 2 {
            completedLevel = lv
            UserDefaults.standard.set(lv, forKey: "pockit.offline.completed")
        }
    }

    func refreshInfo() {
        hasSnapshot = FileManager.default.fileExists(atPath: snapshotURL.path)
        snapshotDate = (try? snapshotURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        let fm = FileManager.default
        var n = 0; var b: Int64 = 0
        if let e = fm.enumerator(at: tilesDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let u as URL in e where u.pathExtension == "jpg" {
                n += 1; b += Int64((try? u.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
            }
        }
        tilesOnDisk = n; bytesOnDisk = b
    }

    // MARK: Copia de los lugares (automática)
    func saveSnapshot(_ json: String) {
        guard let d = json.data(using: .utf8), d.count > 1000 else { return }
        try? d.write(to: snapshotURL, options: .atomic)
        UserDefaults.standard.set(2, forKey: "pockit.offline.snapV")
        cachedSnap = nil
        hasSnapshot = true
        snapshotDate = Date()
        Task { await downloadIcons() }
    }

    /// v2 trae el tipo de cada nombre de zona (pa' mostrarlos según el zoom)
    var snapshotIsStale: Bool {
        (snapshotDate ?? .distantPast).timeIntervalSinceNow < -12 * 3600 ||
        UserDefaults.standard.integer(forKey: "pockit.offline.snapV") < 2
    }

    private struct Snap: Decodable {
        struct Cat: Decodable { let icon: String? }
        struct Tile: Decodable { let url: String?; let tileSize: Double?; let zoomOffset: Int? }
        let crs: [Double]?
        let island: [[Double]]?
        let cats: [String: Cat]?
        let tile: Tile?
        let assetPath: String?
    }
    private var cachedSnap: Snap?
    private func loadSnap() -> Snap? {
        if let cachedSnap { return cachedSnap }
        guard let d = try? Data(contentsOf: snapshotURL) else { return nil }
        cachedSnap = try? JSONDecoder().decode(Snap.self, from: d)
        return cachedSnap
    }

    private func downloadIcons() async {
        guard let s = loadSnap() else { return }
        try? FileManager.default.createDirectory(at: iconsDir, withIntermediateDirectories: true)
        let base = Self.site + (s.assetPath ?? "/images/gta-6/maps/gtab-map/") + "icons/"
        let icons = Set((s.cats ?? [:]).values.compactMap(\.icon).filter { $0.hasPrefix("game-blip") })
        for ic in icons {
            let dest = iconsDir.appendingPathComponent(ic + ".webp")
            if FileManager.default.fileExists(atPath: dest.path) { continue }
            guard let u = URL(string: base + ic + ".webp"), let (d, r) = try? await URLSession.shared.data(from: u),
                  (r as? HTTPURLResponse)?.statusCode == 200 else { continue }
            try? d.write(to: dest, options: .atomic)
        }
    }

    // MARK: Imágenes del mapa (cuando lo pedís)
    /// Cuadritos que hacen falta pa' cubrir la isla hasta ese nivel de zoom.
    func plan(upTo level: Int) -> [(z: Int, x: Int, y: Int)] {
        guard let s = loadSnap(), let t = s.crs, t.count == 4, let isl = s.island, isl.count == 2 else { return [] }
        let size = s.tile?.tileSize ?? 128
        // un poquito de margen alrededor de la isla
        let south = isl[0][0], west = isl[0][1], north = isl[1][0], east = isl[1][1]
        let padLat = (north - south) * 0.05, padLng = (east - west) * 0.05
        var out: [(Int, Int, Int)] = []
        for z in -1...level {
            let scale = pow(2.0, Double(z))
            func px(_ lng: Double) -> Int { Int(floor(scale * (t[0] * lng + t[1]) / size)) }
            func py(_ lat: Double) -> Int { Int(floor(scale * (t[2] * lat + t[3]) / size)) }
            let x0 = px(west - padLng), x1 = px(east + padLng)
            let y0 = py(north + padLat), y1 = py(south - padLat)
            for x in min(x0, x1)...max(x0, x1) { for y in min(y0, y1)...max(y0, y1) { out.append((z, x, y)) } }
        }
        return out
    }

    private func tileFile(z: Int, x: Int, y: Int, offset: Int) -> URL {
        let uz = z + offset
        return tilesDir.appendingPathComponent("\(uz)", isDirectory: true).appendingPathComponent("\(uz),\(y),\(x).jpg")
    }

    func download(level: Int) {
        guard !downloading else { return }
        let jobs = plan(upTo: level)
        guard !jobs.isEmpty, let s = loadSnap() else {
            lastError = L10n.current.s("Abrí el mapa una vez con internet primero.", "Open the map once while online first.")
            return
        }
        let offset = s.tile?.zoomOffset ?? 1
        let template = s.tile?.url ?? "/images/gta-6/maps/tiles/in-game/{z}/{z},{y},{x}.jpg"
        lastError = nil
        downloading = true; done = 0; total = jobs.count
        savedLevel = level
        UserDefaults.standard.set(level, forKey: "pockit.offline.level")
        task = Task { [weak self] in
            guard let self else { return }
            let session = URLSession(configuration: .default)
            var idx = 0
            // 4 a la vez, con calma, pa' no cargarle el servidor a GTABase
            await withTaskGroup(of: Void.self) { group in
                func next() -> (Int, Int, Int)? { guard idx < jobs.count else { return nil }; defer { idx += 1 }; return jobs[idx] }
                for _ in 0..<4 {
                    guard let j = next() else { break }
                    group.addTask { await self.fetch(j, offset: offset, template: template, session: session) }
                }
                while await group.next() != nil {
                    if Task.isCancelled { group.cancelAll(); break }
                    await MainActor.run { self.done += 1 }
                    if let j = next() {
                        group.addTask { await self.fetch(j, offset: offset, template: template, session: session) }
                    }
                }
            }
            let finished = !Task.isCancelled && self.done >= self.total
            self.downloading = false
            if finished {
                self.completedLevel = max(level, self.completedLevel ?? -99)
                UserDefaults.standard.set(self.completedLevel, forKey: "pockit.offline.completed")
            }
            self.refreshInfo()
        }
    }

    nonisolated private func fetch(_ j: (Int, Int, Int), offset: Int, template: String, session: URLSession) async {
        let (z, x, y) = j
        let uz = z + offset
        let dest = await tileFile(z: z, x: x, y: y, offset: offset)
        if FileManager.default.fileExists(atPath: dest.path) { return }
        let path = template.replacingOccurrences(of: "{z}", with: "\(uz)").replacingOccurrences(of: "{x}", with: "\(x)").replacingOccurrences(of: "{y}", with: "\(y)")
        guard let u = URL(string: Self.site + path) else { return }
        guard let (d, r) = try? await session.data(from: u), (r as? HTTPURLResponse)?.statusCode == 200 else { return }
        try? FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? d.write(to: dest, options: .atomic)
    }

    func cancel() { task?.cancel(); downloading = false; refreshInfo() }

    func deleteTiles() {
        cancel()
        try? FileManager.default.removeItem(at: tilesDir)
        savedLevel = nil
        completedLevel = nil
        UserDefaults.standard.removeObject(forKey: "pockit.offline.level")
        UserDefaults.standard.removeObject(forKey: "pockit.offline.completed")
        refreshInfo()
    }
}

/// Sirve el mapa guardado a la WebView: pkoffline://app/… (la página), pkoffline://data/…, tiles/…, icons/…
final class OfflineSchemeHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url, let host = url.host else { return fail(task) }
        let rel = url.path.hasPrefix("/") ? String(url.path.dropFirst()) : url.path
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("OfflineMap", isDirectory: true)
        var file: URL?
        switch host {
        case "app":
            let name = (rel as NSString).deletingPathExtension, ext = (rel as NSString).pathExtension
            file = Bundle.main.url(forResource: name.isEmpty ? "offline-map" : name, withExtension: ext.isEmpty ? "html" : ext)
        case "data": file = root.appendingPathComponent(rel)
        case "tiles": file = root.appendingPathComponent("tiles").appendingPathComponent(rel)
        case "icons": file = root.appendingPathComponent("icons").appendingPathComponent(rel)
        default: file = nil
        }
        guard let file, let data = try? Data(contentsOf: file) else { return notFound(task, url) }
        let mime: String
        switch file.pathExtension.lowercased() {
        case "html": mime = "text/html"
        case "js": mime = "text/javascript"
        case "css": mime = "text/css"
        case "json": mime = "application/json"
        case "jpg", "jpeg": mime = "image/jpeg"
        case "webp": mime = "image/webp"
        default: mime = "application/octet-stream"
        }
        let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                                   headerFields: ["Content-Type": mime, "Content-Length": "\(data.count)", "Access-Control-Allow-Origin": "*"])!
        task.didReceive(resp)
        task.didReceive(data)
        task.didFinish()
    }
    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
    private func fail(_ task: WKURLSchemeTask) { task.didFailWithError(URLError(.badURL)) }
    private func notFound(_ task: WKURLSchemeTask, _ url: URL) {
        let resp = HTTPURLResponse(url: url, statusCode: 404, httpVersion: "HTTP/1.1", headerFields: nil)!
        task.didReceive(resp); task.didReceive(Data()); task.didFinish()
    }
}

/// Hoja "Mapa sin internet".
struct OfflineMapSheet: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var off = OfflineMap.shared
    @State private var level: OfflineMap.Level = .normal

    var body: some View {
        let t = settings.t
        NavigationStack {
            List {
                Section {
                    row(t.s("Lugares, íconos y zonas", "Places, icons and areas"),
                        off.hasSnapshot ? t.s("Guardados ✓", "Saved ✓") : t.s("Abrí el mapa con internet", "Open the map online"))
                    row(t.s("Imágenes del mapa", "Map images"),
                        off.tilesOnDisk > 0 ? "\(off.tilesOnDisk) · \(ByteCountFormatter.string(fromByteCount: off.bytesOnDisk, countStyle: .file))" : t.s("Ninguna", "None"))
                    if let lv = off.completedLevel ?? off.savedLevel, let l = OfflineMap.Level(rawValue: lv) {
                        row(t.s("Nivel", "Level"), l.title(t) + (off.completedLevel != nil ? " ✓" : t.s(" (a medias)", " (partial)")))
                    }
                } header: { SectionTitle(text: t.s("EN ESTE TELÉFONO", "ON THIS PHONE")) }
                footer: {
                    Text(t.s("Tus pines y lugares desbloqueados siempre funcionan sin internet. Si no hay conexión, el mapa abre solo con lo guardado aquí.",
                             "Your pins and unlocked places always work offline. With no connection the map opens with what's saved here."))
                        .font(Theme.text(13)).foregroundStyle(Theme.lilac.opacity(0.85))
                }
                .listRowBackground(Theme.panel)

                Section {
                    Picker(t.s("Detalle", "Detail"), selection: $level) {
                        ForEach(OfflineMap.Level.allCases) { l in Text(l.title(t)).tag(l) }
                    }
                    .pickerStyle(.segmented)
                    let n = off.plan(upTo: level.rawValue).count
                    Text("\(level.blurb(t)) · ~\(n) " + t.s("imágenes", "images") + " · ~" + ByteCountFormatter.string(fromByteCount: Int64(n) * 6_000, countStyle: .file))
                        .font(Theme.text(13)).foregroundStyle(Theme.lilac)
                    if off.downloading {
                        ProgressView(value: Double(off.done), total: Double(max(off.total, 1))).tint(Theme.switchPink)
                        Text("\(off.done) / \(off.total)").font(Theme.text(13)).foregroundStyle(.white)
                        Button(t.s("Pausar", "Pause"), role: .destructive) { off.cancel() }
                    } else if let c = off.completedLevel, c >= level.rawValue {
                        Label(t.s("Listo: este nivel ya está completo en tu teléfono", "Done: this level is fully saved on your phone"), systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Theme.teal)
                    } else {
                        Button { off.download(level: level.rawValue) } label: {
                            Label(off.tilesOnDisk > 0 && (off.savedLevel ?? -99) >= level.rawValue ? t.s("Terminar descarga (quedó a medias)", "Finish download (was interrupted)")
                                  : t.s("Descargar mapa", "Download map"), systemImage: "arrow.down.circle.fill")
                        }
                        .disabled(!off.hasSnapshot)
                    }
                    if let e = off.lastError { Text(e).font(Theme.text(13)).foregroundStyle(Theme.coral) }
                } header: { SectionTitle(text: t.s("DESCARGAR", "DOWNLOAD")) }
                footer: {
                    Text(t.s("Mejor con Wi-Fi. Si se corta, tocá de nuevo y sigue donde quedó. Es solo pa' tu uso; se queda en este teléfono.",
                             "Best on Wi-Fi. If it stops, tap again to resume. For your own use; it stays on this phone."))
                        .font(Theme.text(13)).foregroundStyle(Theme.lilac.opacity(0.85))
                }
                .listRowBackground(Theme.panel)

                if off.tilesOnDisk > 0 {
                    Section {
                        Button(role: .destructive) { off.deleteTiles() } label: { Label(t.s("Borrar imágenes guardadas", "Delete saved images"), systemImage: "trash") }
                    }
                    .listRowBackground(Theme.panel)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.menu.ignoresSafeArea())
            .navigationTitle(t.s("Mapa sin internet", "Offline map"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                off.refreshInfo()
                if let lv = off.completedLevel ?? off.savedLevel, let l = OfflineMap.Level(rawValue: lv) { level = l }
            }
        }
    }

    private func row(_ a: String, _ b: String) -> some View {
        HStack { Text(a).foregroundStyle(.white); Spacer(); Text(b).foregroundStyle(Theme.lilac) }.font(Theme.text(15))
    }
}
