import Foundation
import SwiftUI

// MARK: - Modelos (Codable, listos pa' sincronizar con pockit-datos en la siguiente build)

struct Pendiente: Codable, Identifiable, Hashable {
    var id = UUID()
    var text: String
    var createdAt = Date()
    var done = false
    var doneAt: Date?
    /// "marisol" (vino de una etiqueta tip) o "manual".
    var source = "manual"
}

struct Nota: Codable, Identifiable, Hashable {
    var id = UUID()
    var text: String
    var createdAt = Date()
}

struct MoneySnapshot: Codable, Identifiable, Hashable {
    var id = UUID()
    var at = Date()
    var bank: Int
    var app: Int
    var home: Int
    var source = "manual"
    var total: Int { bank + app + home }
}

struct Propiedad: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var isBusiness = false
    var note = ""
    var createdAt = Date()
}

struct CollectibleItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var foundAt = Date()
}

struct CollectibleCategory: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    /// Total de la categoría (viene de Marisol). Solo se muestra cuando la completas.
    var total: Int?
    var items: [CollectibleItem] = []
    var isComplete: Bool { if let total, total > 0 { return items.count >= total }; return false }
}

struct MissionEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var pct: Int?
    var at = Date()
}

struct PockitData: Codable {
    var version = 1
    var pendientes: [Pendiente] = []
    var libreta: [Nota] = []
    var money: [MoneySnapshot] = []
    var propiedadesUnlocked = false
    var propiedades: [Propiedad] = []
    var collectibles: [CollectibleCategory] = []
    var missions: [MissionEntry] = []
    var importedEventLog = false
    var updatedAt = Date()
}

// MARK: - Store

/// Todos los datos de Pockit fuera del chat. Se guardan en un JSON local (Application Support).
/// Aviso nativo cuando Marisol anota algo (tarjetita encima de la barra).
struct StoreNotice: Identifiable, Equatable {
    let id = UUID()
    let emoji: String
    let text: String
}

@MainActor
final class PockitStore: ObservableObject {
    @Published private(set) var data = PockitData()
    @Published var notice: StoreNotice?
    /// Mientras se importa events.json no se muestran avisos.
    private var quiet = false

    private let url: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("pockit-data.json")
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; e.outputFormatting = [.prettyPrinted, .sortedKeys]; return e
    }()
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }()

    init() {
        if let raw = try? Data(contentsOf: url), let decoded = try? Self.decoder.decode(PockitData.self, from: raw) {
            data = decoded
        }
        if !data.importedEventLog { importEventLog() }
    }

    private func mutate(_ change: (inout PockitData) -> Void) {
        var copy = data
        change(&copy)
        copy.updatedAt = Date()
        data = copy
        if let raw = try? Self.encoder.encode(copy) { try? raw.write(to: url, options: .atomic) }
    }

    /// Las etiquetas que llegaron antes de la fase 3 quedaron en events.json: se importan una vez.
    private func importEventLog() {
        let old = (try? JSONDecoder().decode([[String: String]].self, from: Data(contentsOf: EventLog.url))) ?? []
        let iso = ISO8601DateFormatter()
        quiet = true
        defer { quiet = false }
        for entry in old { ingest(entry, at: entry["at"].flatMap { iso.date(from: $0) } ?? Date()) }
        mutate { $0.importedEventLog = true }
    }

    // MARK: Etiquetas de Marisol

    func ingest(_ tag: [String: String], at date: Date = Date()) {
        if let cat = tag["cat"], let item = tag["item"] {
            let before = collectiblesFound
            addCollectible(category: cat, item: item, total: tag["total"].flatMap(Self.number), at: date)
            if collectiblesFound > before { announce("🃏", lang: "Collectible: \(item)") }
        }
        if let tip = tag["tip"]?.trimmingCharacters(in: .whitespacesAndNewlines), !tip.isEmpty {
            let before = data.pendientes.count
            addPendiente(tip, source: "marisol", at: date)
            if data.pendientes.count > before { announce("📌", lang: tip) }
        }
        if tag["bank"] != nil || tag["app"] != nil || tag["home"] != nil {
            let last = data.money.last
            let snap = MoneySnapshot(
                at: date,
                bank: tag["bank"].flatMap(Self.number) ?? last?.bank ?? 0,
                app: tag["app"].flatMap(Self.number) ?? last?.app ?? 0,
                home: tag["home"].flatMap(Self.number) ?? last?.home ?? 0,
                source: "marisol")
            let before = data.money.count
            addMoney(snap)
            if data.money.count > before { announce("💰", lang: "Money: \(Fmt.money(snap.total))") }
        }
        if let mission = tag["mission"]?.trimmingCharacters(in: .whitespaces), !mission.isEmpty {
            let before = data.missions.count
            logMission(mission, pct: tag["pct"].flatMap(Self.number), at: date)
            if data.missions.count > before { announce("📍", lang: mission) }
        }
    }

    private func announce(_ emoji: String, lang text: String) {
        guard !quiet else { return }
        notice = StoreNotice(emoji: emoji, text: text)
    }

    static func number(_ s: String) -> Int? {
        let lower = s.lowercased()
        let digits = lower.filter { $0.isNumber || $0 == "." }
        guard var value = Double(digits) else { return nil }
        if lower.hasSuffix("k") { value *= 1_000 }
        if lower.hasSuffix("m") { value *= 1_000_000 }
        return Int(value.rounded())
    }

    // MARK: Pendientes y libreta

    var openPendientes: [Pendiente] { data.pendientes.filter { !$0.done }.sorted { $0.createdAt > $1.createdAt } }
    var donePendientes: [Pendiente] { data.pendientes.filter(\.done).sorted { ($0.doneAt ?? $0.createdAt) > ($1.doneAt ?? $1.createdAt) } }

    func addPendiente(_ text: String, source: String = "manual", at date: Date = Date()) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        if data.pendientes.contains(where: { $0.text.caseInsensitiveCompare(clean) == .orderedSame }) { return }
        mutate { $0.pendientes.append(Pendiente(text: clean, createdAt: date, source: source)) }
    }

    func toggle(_ p: Pendiente) {
        mutate { d in
            guard let i = d.pendientes.firstIndex(where: { $0.id == p.id }) else { return }
            d.pendientes[i].done.toggle()
            d.pendientes[i].doneAt = d.pendientes[i].done ? Date() : nil
        }
    }

    func delete(_ p: Pendiente) { mutate { $0.pendientes.removeAll { $0.id == p.id } } }

    func moveToLibreta(_ p: Pendiente) {
        mutate { d in
            d.pendientes.removeAll { $0.id == p.id }
            d.libreta.append(Nota(text: p.text))
        }
    }

    func addNota(_ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        mutate { $0.libreta.append(Nota(text: clean)) }
    }

    func updateNota(_ n: Nota, text: String) {
        mutate { d in
            guard let i = d.libreta.firstIndex(where: { $0.id == n.id }) else { return }
            d.libreta[i].text = text
        }
    }

    func delete(_ n: Nota) { mutate { $0.libreta.removeAll { $0.id == n.id } } }

    // MARK: Money

    var currentMoney: MoneySnapshot? { data.money.last }

    func addMoney(_ snap: MoneySnapshot) {
        // Si es igual al último, no se repite (p. ej. lo actualizas a mano y Marisol lo confirma).
        if let last = data.money.last, last.bank == snap.bank, last.app == snap.app, last.home == snap.home { return }
        mutate { $0.money.append(snap) }
    }

    func delete(_ snap: MoneySnapshot) { mutate { $0.money.removeAll { $0.id == snap.id } } }

    func setPropiedadesUnlocked(_ on: Bool) { mutate { $0.propiedadesUnlocked = on } }

    func addPropiedad(_ p: Propiedad) { mutate { $0.propiedades.append(p) } }

    func delete(_ p: Propiedad) { mutate { $0.propiedades.removeAll { $0.id == p.id } } }

    // MARK: Collectibles

    var collectiblesFound: Int { data.collectibles.reduce(0) { $0 + $1.items.count } }

    func addCollectible(category: String, item: String, total: Int?, at date: Date = Date()) {
        let cat = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = item.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cat.isEmpty, !name.isEmpty else { return }
        mutate { d in
            var i = d.collectibles.firstIndex { $0.name.caseInsensitiveCompare(cat) == .orderedSame }
            if i == nil { d.collectibles.append(CollectibleCategory(name: cat)); i = d.collectibles.count - 1 }
            guard let idx = i else { return }
            if let total, total > 0 { d.collectibles[idx].total = total }
            if !d.collectibles[idx].items.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                d.collectibles[idx].items.append(CollectibleItem(name: name, foundAt: date))
            }
        }
    }

    func delete(_ item: CollectibleItem, in category: CollectibleCategory) {
        mutate { d in
            guard let i = d.collectibles.firstIndex(where: { $0.id == category.id }) else { return }
            d.collectibles[i].items.removeAll { $0.id == item.id }
            if d.collectibles[i].items.isEmpty { d.collectibles.remove(at: i) }
        }
    }

    // MARK: Misiones

    func logMission(_ name: String, pct: Int?, at date: Date = Date()) {
        if let last = data.missions.last, last.name.caseInsensitiveCompare(name) == .orderedSame {
            if let pct, last.pct != pct { mutate { $0.missions[$0.missions.count - 1].pct = pct } }
            return
        }
        mutate { $0.missions.append(MissionEntry(name: name, pct: pct, at: date)) }
    }

    func delete(_ m: MissionEntry) { mutate { $0.missions.removeAll { $0.id == m.id } } }
}

enum Fmt {
    static func money(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.locale = Locale(identifier: "en_US")
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: n)) ?? "$\(n)"
    }

    static func date(_ d: Date, lang: AppLanguage) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: lang == .es ? "es_CR" : "en_US")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: d)
    }

    static func relative(_ d: Date, lang: AppLanguage) -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: lang == .es ? "es_CR" : "en_US")
        f.unitsStyle = .short
        return f.localizedString(for: d, relativeTo: Date())
    }
}
