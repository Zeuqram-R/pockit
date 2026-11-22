import Foundation

/// Lo que el widget necesita saber, escrito por la app en el contenedor compartido (App Group).
struct WidgetSnapshot: Codable {
    var pct: Int = -1
    var mission: String = ""
    var money: Int?
    var pendientes: [String] = []
    var collectibles: Int = 0
    var mood: String = "neutral"
    var lang: String = "es"
    var updatedAt = Date()

    static let group = "group.com.zeuqram.pockit"
    static var url: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?.appendingPathComponent("widget.json")
    }
    static func load() -> WidgetSnapshot? {
        guard let url, let d = try? Data(contentsOf: url) else { return nil }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        return try? dec.decode(WidgetSnapshot.self, from: d)
    }
    func save() -> Bool {
        guard let url = Self.url else { return false }
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        guard let d = try? enc.encode(self) else { return false }
        return (try? d.write(to: url, options: .atomic)) != nil
    }
}
