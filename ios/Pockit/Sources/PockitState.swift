import SwiftUI
import UIKit

enum Mood: String, CaseIterable {
    case neutral, feliz, emocionada, sorprendida, impresionada, triste, enojada, chismosa
}

/// Estado que viene de las etiquetas de Marisol y de los botones de la app.
@MainActor
final class PockitState: ObservableObject {
    @Published var mood: Mood = .neutral
    @Published var lastReplyHadSpoiler = false
    /// Marisol está dando pistas de un secreto: se muestran "Otra pista" y "Dime ya".
    @Published var hintsOpen = false

    @AppStorage("pockit.spoilersOn") var spoilersOn = false {
        willSet { objectWillChange.send() }
    }
    @AppStorage("pockit.progress.pct") var progressPct: Int = -1 {
        willSet { objectWillChange.send() }
    }
    @AppStorage("pockit.progress.mission") var progressMission: String = "" {
        willSet { objectWillChange.send() }
    }

    /// Etiquetas ya procesadas (pa' no repetirlas al reabrir un chat viejo).
    private var seenKeys: Set<String>
    private let seenKey = "pockit.seenTagKeys"

    init() {
        seenKeys = Set(UserDefaults.standard.stringArray(forKey: "pockit.seenTagKeys") ?? [])
    }

    var device: String {
        if ProcessInfo.processInfo.isiOSAppOnMac { return "Mac" }
        switch UIDevice.current.userInterfaceIdiom {
        case .pad: return "iPad"
        case .mac: return "Mac"
        default: return "iPhone"
        }
    }

    func prefix(lang: AppLanguage) -> String {
        "⟦device:\(device)⟧ ⟦lang:\(lang.rawValue)⟧ "
    }

    var progressSummary: String? {
        guard progressPct >= 0 else { return progressMission.isEmpty ? nil : progressMission }
        return progressMission.isEmpty ? "\(progressPct)%" : "\(progressPct)% · \(progressMission)"
    }

    /// Recibe un lote de etiquetas del chat. El último elemento es la respuesta más reciente.
    func handle(items: [[String: Any]]) {
        var newestMood: Mood?
        var newestSpoiler: Bool?
        var newestHints = false
        var changedSeen = false

        for (index, item) in items.enumerated() {
            guard let key = item["key"] as? String,
                  let tags = item["tags"] as? [[String: String]] else { continue }
            let isNewest = index == items.count - 1
            let isNew = !seenKeys.contains(key)

            for tag in tags {
                // La cara y el aviso de spoiler siguen siempre a la respuesta más reciente en pantalla.
                if isNewest, let m = tag["mood"], let mood = Mood(rawValue: m) { newestMood = mood }
                if isNewest, let s = tag["spoiler"] { newestSpoiler = (s == "yes") }
                if isNewest, tag["hints"] == "open" { newestHints = true }
                guard isNew else { continue }
                apply(tag)
            }
            if isNew { seenKeys.insert(key); changedSeen = true }
        }

        if let m = newestMood, m != mood { mood = m }
        if let s = newestSpoiler { lastReplyHadSpoiler = s }
        if !items.isEmpty, newestHints != hintsOpen { hintsOpen = newestHints }
        if changedSeen {
            UserDefaults.standard.set(Array(seenKeys.suffix(2000)), forKey: seenKey)
        }
    }

    private func apply(_ tag: [String: String]) {
        if let pct = tag["pct"], let n = Int(pct.filter(\.isNumber)) { progressPct = min(100, max(0, n)) }
        if let mission = tag["mission"], !mission.isEmpty { progressMission = mission }
        // Collectibles, tips y money se guardan pa' la fase 3 (tracker).
        if tag["collectible"] != nil || tag["cat"] != nil || tag["tip"] != nil
            || tag["bank"] != nil || tag["app"] != nil || tag["home"] != nil {
            EventLog.append(tag)
        }
    }
}

/// Registro local de eventos (collectibles, tips, money) que la fase 3 va a leer.
enum EventLog {
    static var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("events.json")
    }

    static func append(_ tag: [String: String]) {
        var all = (try? JSONDecoder().decode([[String: String]].self, from: Data(contentsOf: url))) ?? []
        var entry = tag
        entry["at"] = ISO8601DateFormatter().string(from: Date())
        all.append(entry)
        if let data = try? JSONEncoder().encode(all) { try? data.write(to: url, options: .atomic) }
    }
}
