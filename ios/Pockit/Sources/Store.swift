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
    /// Variante (p. ej. "Bronze Legacy" en las cartas).
    var variant: String?

    init(name: String, foundAt: Date = Date(), variant: String? = nil) {
        self.name = name; self.foundAt = foundAt; self.variant = variant
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        foundAt = try c.decodeIfPresent(Date.self, forKey: .foundAt) ?? Date()
        variant = try c.decodeIfPresent(String.self, forKey: .variant)
    }
}

/// Subcategoría de collectibles (p. ej. "Meditations"), dentro de una categoría general (p. ej. "Exploration").
struct CollectibleCategory: Codable, Identifiable, Hashable {
    var id = UUID()
    /// Categoría general: Kenton's Treasures, Collectible Cards, Waink Locations, Exploration…
    var group: String
    var name: String
    /// Total de la subcategoría (viene de Marisol). Solo se muestra cuando la completas.
    var total: Int?
    var items: [CollectibleItem] = []
    /// Encontrados que el juego no deja ver cuáles son (solo el número).
    var extraCount = 0

    var count: Int { items.count + extraCount }
    var isComplete: Bool { if let total, total > 0 { return count >= total }; return false }

    init(group: String, name: String, total: Int? = nil, items: [CollectibleItem] = [], extraCount: Int = 0) {
        self.group = group; self.name = name; self.total = total; self.items = items; self.extraCount = extraCount
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        group = try c.decodeIfPresent(String.self, forKey: .group) ?? name
        total = try c.decodeIfPresent(Int.self, forKey: .total)
        items = try c.decodeIfPresent([CollectibleItem].self, forKey: .items) ?? []
        extraCount = try c.decodeIfPresent(Int.self, forKey: .extraCount) ?? 0
    }
}

/// Orden fijo de las categorías generales (como en el menú Progress > Collections del juego).
enum CollectibleGroups {
    static let order = ["Kenton's Treasures", "Collectible Cards", "Waink Locations", "Exploration", "Animals"]
}

// MARK: - Progress (Challenges y Activities) y Garage

struct ChallengeCategory: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var total: Int
    var done: [String] = []
}

struct ActivityStat: Codable, Hashable, Identifiable {
    var id: String { label }
    var label: String
    var value: Int
    var max: Int?
}

struct ActivityItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var discovered = true
    var level: String?          // Beginner / Intermediate…
    var stats: [ActivityStat] = []
    var best: String?           // mejor tiempo o puntaje
    var medal: String?          // Bronze / Silver / Gold
    var check: Bool?            // "Full challenge complete", "EIRS challenge completed"…
    var checkLabel: String?
}

struct ActivityCategory: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var items: [ActivityItem] = []
    var discoveredCount: Int { items.filter(\.discovered).count }
}

struct Vehicle: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var kind: String            // car, moto, boat, bike, air, other
    var location = ""
    var notes = ""
}

/// Una cuenta dentro de BUCKME (p. ej. "Checking Account", "Family Savings").
struct BuckmeAccount: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var amount: Int
}

struct MissionEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var pct: Int?
    var at = Date()
}

/// Pin en el mapa propio de Jose (x/y van de 0 a 1 sobre la imagen).
struct MapPin: Codable, Identifiable, Hashable {
    var id = UUID()
    var x: Double
    var y: Double
    var name: String
    var note: String = ""
    var kind: String = "pin"   // pin, secreto, coleccionable, foto, negocio
    var done = false
    var at = Date()
}

struct PockitData: Codable {
    var version = 2
    var pendientes: [Pendiente] = []
    var libreta: [Nota] = []
    var money: [MoneySnapshot] = []
    var buckme: [BuckmeAccount] = []
    var propiedadesUnlocked = false
    var propiedades: [Propiedad] = []
    var collectibles: [CollectibleCategory] = []
    var missions: [MissionEntry] = []
    var importedEventLog = false
    var seededV2 = false
    var seededV3 = false
    var challenges: [ChallengeCategory] = []
    var activities: [ActivityCategory] = []
    var vehicles: [Vehicle] = []
    var seededV4 = false
    var seededV5 = false
    var pins: [MapPin] = []
    var updatedAt = Date()

    init() {}

    // Campos que falten (versiones viejas del archivo) quedan con su valor por defecto.
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        pendientes = try c.decodeIfPresent([Pendiente].self, forKey: .pendientes) ?? []
        libreta = try c.decodeIfPresent([Nota].self, forKey: .libreta) ?? []
        money = try c.decodeIfPresent([MoneySnapshot].self, forKey: .money) ?? []
        buckme = try c.decodeIfPresent([BuckmeAccount].self, forKey: .buckme) ?? []
        propiedadesUnlocked = try c.decodeIfPresent(Bool.self, forKey: .propiedadesUnlocked) ?? false
        propiedades = try c.decodeIfPresent([Propiedad].self, forKey: .propiedades) ?? []
        collectibles = try c.decodeIfPresent([CollectibleCategory].self, forKey: .collectibles) ?? []
        missions = try c.decodeIfPresent([MissionEntry].self, forKey: .missions) ?? []
        importedEventLog = try c.decodeIfPresent(Bool.self, forKey: .importedEventLog) ?? false
        seededV2 = try c.decodeIfPresent(Bool.self, forKey: .seededV2) ?? false
        seededV3 = try c.decodeIfPresent(Bool.self, forKey: .seededV3) ?? false
        challenges = try c.decodeIfPresent([ChallengeCategory].self, forKey: .challenges) ?? []
        activities = try c.decodeIfPresent([ActivityCategory].self, forKey: .activities) ?? []
        vehicles = try c.decodeIfPresent([Vehicle].self, forKey: .vehicles) ?? []
        seededV4 = try c.decodeIfPresent(Bool.self, forKey: .seededV4) ?? false
        seededV5 = try c.decodeIfPresent(Bool.self, forKey: .seededV5) ?? false
        pins = try c.decodeIfPresent([MapPin].self, forKey: .pins) ?? []
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
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
    /// Avisos en pantalla (se apilan; cada uno se va solo a los 3 s).
    @Published var notices: [StoreNotice] = []
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
        if !data.seededV2 { seedV2() }
        if !data.seededV3 { seedV3() }
        if !data.seededV4 { seedV4() }
        if !data.seededV5 {
            mutate { d in
                if let i = d.vehicles.firstIndex(where: { $0.name == "Bombora S23" }) { d.vehicles[i].kind = "boat" }
                for c in d.activities.indices {
                    for i in d.activities[c].items.indices where d.activities[c].items[i].name == "Rodgers Ranch ??? Range" {
                        d.activities[c].items[i].name = "Rodgers Ranch Hunting Range"
                    }
                }
                d.seededV5 = true
            }
        }
    }

    /// 21 nov: Challenges, Activities (solo lo que mide avance) y Garage, como los contó Jose.
    private func seedV4() {
        func ch(_ n: String, _ done: [String] = []) -> ChallengeCategory { ChallengeCategory(name: n, total: 10, done: done) }
        func st(_ l: String, _ v: Int = 0, _ m: Int? = nil) -> ActivityStat { ActivityStat(label: l, value: v, max: m) }
        func hidden() -> ActivityItem { ActivityItem(name: "???", discovered: false) }
        func golf(_ n: String) -> ActivityItem { ActivityItem(name: n, stats: [st("Holes in one")], best: "9: 0 · 18: 0") }
        func trial(_ n: String) -> ActivityItem { ActivityItem(name: n, best: "00:00.00") }
        func range(_ n: String, _ lvl: String, time: Bool) -> ActivityItem { ActivityItem(name: n, level: lvl, stats: [st("Bullseyes")], best: time ? "00:00.00" : "0") }
        let challenges = [ch("Combat", ["Speed Kills"]), ch("Criminal"), ch("Exploration"), ch("Fitness"), ch("Shopping"),
                          ch("Sports"), ch("Survival", ["Alligator Kills"]), ch("Vehicle", ["Vehicle Discovery"])]
        let activities: [ActivityCategory] = [
            ActivityCategory(name: "Sports", items: [
                ActivityItem(name: "Fishing", stats: [st("Species caught", 1, 35)], best: "Stoplight Parrotfish · 1 kg"),
                hidden(),
                golf("King Gator Adventure Golf"),
                golf("Frontier Adventure Golf"),
                ActivityItem(name: "Dino Golf Challenge", stats: [st("Holes in one")], best: "0", check: false, checkLabel: "Full challenge complete"),
                ActivityItem(name: "Leaf Links Golf Challenge", stats: [st("Holes in one")], best: "0", check: false, checkLabel: "Full challenge complete"),
                ActivityItem(name: "Mount Hailes Golf Challenge", stats: [st("Holes in one")], best: "0", check: false, checkLabel: "Full challenge complete"),
                ActivityItem(name: "Basketball", stats: [st("Hoops scored", 1, 100)], best: "Streak 6", check: false, checkLabel: "EIRS challenge completed"),
                ActivityItem(name: "Pool", stats: [st("Tables played", 0, 17), st("Opponents defeated", 0, 7)]),
            ]),
            ActivityCategory(name: "Racing", items: [
                hidden(), hidden(), hidden(),
                ActivityItem(name: "Boone Speedway", stats: [st("Unique races entered", 0, 2), st("Unique races won", 0, 2)]),
                hidden(), hidden(),
            ]),
            ActivityCategory(name: "Race Challenges", items: [
                hidden(), hidden(),
                trial("Boone Speedway Trial"), trial("Gellhorn Raceway Trial"),
                hidden(), hidden(),
                ActivityItem(name: "Mud Club Air Time Stunt Run", best: "0"),
                trial("Mud Club Drag Trial"), trial("Mud Club Hill Climb Trial"),
                hidden(),
                trial("Mud Club Oval Trial"), trial("Mud Club Swamp Run Trial"),
                hidden(),
            ]),
            ActivityCategory(name: "Shooting Ranges", items: [
                ActivityItem(name: "Rodgers Ranch & Shooting Range", stats: [st("Ranges unlocked", 0, 6), st("Medals", 0, 12)]),
                range("Rodgers Ranch Saloon Range", "Beginner", time: false),
                range("Rodgers Ranch Hunting Range", "Beginner", time: false),
                range("Rodgers Ranch Zombie Range", "Beginner", time: false),
                range("Rodgers Ranch Cops & Robbers Range", "Beginner", time: false),
                range("Rodgers Ranch Market Range", "Beginner", time: false),
                range("Rodgers Ranch Alien Range", "Beginner", time: false),
                ActivityItem(name: "Griffin Shooting Range", stats: [st("Ranges unlocked", 0, 6), st("Medals", 0, 54)]),
                range("Griffin 3-Point Range", "Beginner", time: true),
                range("Griffin Hook Range", "Beginner", time: true),
                range("Griffin Loop Range", "Beginner", time: true),
                range("Griffin Maze Range", "Intermediate", time: true),
                range("Griffin Compound Range", "Intermediate", time: true),
                range("Griffin Village Range", "Intermediate", time: true),
            ]),
            ActivityCategory(name: "Games", items: [hidden(), ActivityItem(name: "Street Trash 3: Dezombifier"), hidden(), ActivityItem(name: "Tenebrae Lux")]),
            ActivityCategory(name: "Stunts", items: [
                ActivityItem(name: "Stunt Jumps", stats: [st("Discovered", 5, 130), st("Completed", 5, 130), st("Challenges completed", 2, 130)]),
                ActivityItem(name: "Under the Bridges", stats: [st("Discovered", 0, 202), st("Completed", 0, 202)]),
                ActivityItem(name: "Knife Flights", stats: [st("Discovered", 0, 40), st("Completed", 0, 40)]),
                ActivityItem(name: "Base Jumps", stats: [st("Discovered", 0, 25), st("Completed", 0, 25), st("Par times beaten", 0, 25)]),
            ]),
            ActivityCategory(name: "Top Fun Drones", items: Array(repeating: 0, count: 14).map { _ in hidden() }),
        ]
        let home = "Casa del inicio (Jason)"
        let vehicles = [
            Vehicle(name: "'70 Vapid Ganado", kind: "car", location: home, notes: "Ultimate Edition: Retro Build gratis en Coastal Auto Care (Key Lento), en Full Kits / Pro Builds. Solo se usa en el Chapter 1."),
            Vehicle(name: "Dinka Enduro", kind: "moto", location: home, notes: "Ultimate Edition (army fatigue). Solo se usa en el Chapter 1."),
            Vehicle(name: "Bombora S23", kind: "boat", location: home),
            Vehicle(name: "Bicicleta", kind: "bike", location: home, notes: "Viene con la casa del inicio."),
        ]
        mutate { d in
            if d.challenges.isEmpty { d.challenges = challenges }
            if d.activities.isEmpty { d.activities = activities }
            if d.vehicles.isEmpty { d.vehicles = vehicles }
            d.seededV4 = true
        }
    }

    // MARK: Challenges / Activities / Garage

    func markChallenge(category: String, item: String, done: Bool = true) {
        let name = item.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        mutate { d in
            guard let i = d.challenges.firstIndex(where: { $0.name.caseInsensitiveCompare(category) == .orderedSame }) else { return }
            d.challenges[i].done.removeAll { $0.caseInsensitiveCompare(name) == .orderedSame }
            if done { d.challenges[i].done.append(name) }
        }
    }

    func updateActivity(_ item: ActivityItem, in cat: ActivityCategory) {
        mutate { d in
            guard let c = d.activities.firstIndex(where: { $0.id == cat.id }),
                  let i = d.activities[c].items.firstIndex(where: { $0.id == item.id }) else { return }
            d.activities[c].items[i] = item
        }
    }

    /// Etiqueta de Marisol: ⟦pockit activity cat="Stunts" item="Stunt Jumps" stat="Completed" value=6⟧
    func ingestActivity(_ tag: [String: String]) {
        guard let cat = tag["cat"], let name = tag["item"] else { return }
        mutate { d in
            guard let c = d.activities.firstIndex(where: { $0.name.caseInsensitiveCompare(cat) == .orderedSame }) else { return }
            var i = d.activities[c].items.firstIndex(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })
            if i == nil, let slot = d.activities[c].items.firstIndex(where: { !$0.discovered }) {
                d.activities[c].items[slot] = ActivityItem(name: name)
                i = slot
            }
            guard let idx = i else { return }
            var it = d.activities[c].items[idx]
            it.discovered = true
            if let label = tag["stat"], let v = tag["value"].flatMap(Self.number) {
                if let s = it.stats.firstIndex(where: { $0.label.caseInsensitiveCompare(label) == .orderedSame }) { it.stats[s].value = v }
                else { it.stats.append(ActivityStat(label: label, value: v, max: tag["max"].flatMap(Self.number))) }
            }
            if let m = tag["medal"] { it.medal = m }
            if let b = tag["best"] { it.best = b }
            if let ck = tag["done"] { it.check = ["yes", "true", "1", "si", "sí"].contains(ck.lowercased()) }
            d.activities[c].items[idx] = it
        }
    }

    func saveVehicle(_ v: Vehicle) {
        mutate { d in
            if let i = d.vehicles.firstIndex(where: { $0.id == v.id }) { d.vehicles[i] = v } else { d.vehicles.append(v) }
        }
    }

    func delete(_ v: Vehicle) { mutate { $0.vehicles.removeAll { $0.id == v.id } } }

    /// 21 nov (noche): Kenton's Treasures se divide en sus tres "Nuestra Señora" (con doubloons)
    /// y se agrega Animals con sus 8 subcategorías.
    private func seedV3() {
        mutate { d in
            d.collectibles.removeAll { $0.group == "Kenton's Treasures" }
            d.collectibles.insert(contentsOf: [
                CollectibleCategory(group: "Kenton's Treasures", name: "Nuestra Señora del Ocio", total: 10, extraCount: 10),
                CollectibleCategory(group: "Kenton's Treasures", name: "Nuestra Señora de la Ética Laxa"),
                CollectibleCategory(group: "Kenton's Treasures", name: "Nuestra Señora de la Noche"),
            ], at: 0)
            let animals: [CollectibleCategory] = [
                CollectibleCategory(group: "Animals", name: "Hunting", total: 61, items: [CollectibleItem(name: "Whitetail Deer")]),
                CollectibleCategory(group: "Animals", name: "Fishing", total: 35, items: [CollectibleItem(name: "Stoplight Parrotfish"), CollectibleItem(name: "Permit")]),
                CollectibleCategory(group: "Animals", name: "Mammals", total: 18),
                CollectibleCategory(group: "Animals", name: "Cats and Dogs", total: 34, items: [CollectibleItem(name: "Balinese"), CollectibleItem(name: "German Shepherd")]),
                CollectibleCategory(group: "Animals", name: "Reptiles and Amphibians", total: 6),
                CollectibleCategory(group: "Animals", name: "Birds", total: 60, items: [CollectibleItem(name: "Eastern Brown Pelican"), CollectibleItem(name: "Leghorn Chicken")]),
                CollectibleCategory(group: "Animals", name: "Aquatic", total: 18, items: [CollectibleItem(name: "Atlantic Goliath Grouper")]),
                CollectibleCategory(group: "Animals", name: "Other", total: 23),
            ]
            for a in animals where !d.collectibles.contains(where: { $0.group == "Animals" && $0.name == a.name }) {
                d.collectibles.append(a)
            }
            d.seededV3 = true
        }
    }

    /// Lo que Jose ya tenía en el juego el 21 de nov (lo contó él): categorías de collectibles y cuentas de BUCKME.
    private func seedV2() {
        let seed: [CollectibleCategory] = [
            CollectibleCategory(group: "Kenton's Treasures", name: "Kenton's Treasures", items: [
                CollectibleItem(name: "Nuestra Señora del Ocio"),
                CollectibleItem(name: "Nuestra Señora de la Ética Laxa"),
                CollectibleItem(name: "Nuestra Señora de la Noche"),
            ]),
            CollectibleCategory(group: "Collectible Cards", name: "Los Santos Pounders", items: [
                CollectibleItem(name: "Laki Maivia", variant: "Bronze Legacy"),
            ]),
            CollectibleCategory(group: "Collectible Cards", name: "Nine1Nine Dancers", items: [
                CollectibleItem(name: "Aimie", variant: "Special Pink"),
            ]),
            CollectibleCategory(group: "Waink Locations", name: "Landmarks"),
            CollectibleCategory(group: "Waink Locations", name: "Curiosities"),
            CollectibleCategory(group: "Waink Locations", name: "Sculptures"),
            CollectibleCategory(group: "Exploration", name: "Underwater Discoveries", extraCount: 1),
            CollectibleCategory(group: "Exploration", name: "Magazines, Books & Comics", extraCount: 5),
            CollectibleCategory(group: "Exploration", name: "Meditations", items: [
                CollectibleItem(name: "Meditation spot del dock de la casa"),
            ]),
        ]
        let accounts = [BuckmeAccount(name: "Checking Account", amount: 1_533), BuckmeAccount(name: "Family Savings", amount: 5_000)]
        mutate { d in
            d.collectibles = seed
            if d.buckme.isEmpty { d.buckme = accounts }
            d.seededV2 = true
        }
        syncBuckmeTotal()
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
        let type = tag["_type"] ?? ""
        if let cat = tag["cat"], type.isEmpty || type == "collectible" {
            let before = collectiblesFound
            if let item = tag["item"] {
                addCollectible(category: cat, item: item, total: tag["total"].flatMap(Self.number),
                               group: tag["group"], variant: tag["variant"], at: date)
                if collectiblesFound > before { announce("🃏", lang: "\(L10n.current.s("Coleccionable", "Collectible")): \(L10n.current.data(item))") }
            } else if let n = tag["count"].flatMap(Self.number) {
                setCollectibleCount(category: cat, count: n, total: tag["total"].flatMap(Self.number), group: tag["group"])
                if collectiblesFound > before { announce("🃏", lang: "\(cat): \(n)") }
            }
        }
        if type == "challenge", let c = tag["cat"], let item = tag["item"] {
            markChallenge(category: c, item: item)
            announce("🏆", lang: "\(c): \(item)")
            return
        }
        if type == "activity" {
            ingestActivity(tag)
            if let item = tag["item"] { announce("🎯", lang: item) }
            return
        }
        if type == "vehicle", let v = tag["name"], !v.isEmpty {
            if !data.vehicles.contains(where: { $0.name.caseInsensitiveCompare(v) == .orderedSame }) {
                saveVehicle(Vehicle(name: v, kind: tag["kind"] ?? "car", location: tag["where"] ?? ""))
                announce("🚗", lang: L10n.current.data(v))
            }
        }
        if let name = tag["buckme"] ?? (tag["account"]), let amount = tag["amount"].flatMap(Self.number) {
            setBuckme(name: name, amount: amount)
            announce("💰", lang: "BUCKME · \(name): \(Fmt.money(amount))")
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
            if data.money.count > before { announce("💰", lang: "\(L10n.current.s("Dinero", "Money")): \(Fmt.money(snap.total))") }
        }
        if let mission = tag["mission"]?.trimmingCharacters(in: .whitespaces), !mission.isEmpty {
            let before = data.missions.count
            logMission(mission, pct: tag["pct"].flatMap(Self.number), at: date)
            if data.missions.count > before { announce("📍", lang: mission) }
        }
    }

    private func announce(_ emoji: String, lang text: String) {
        guard !quiet else { return }
        notices.append(StoreNotice(emoji: emoji, text: text))
        if notices.count > 4 { notices.removeFirst(notices.count - 4) }
    }

    func dismissNotice(_ id: UUID) { notices.removeAll { $0.id == id } }

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

    var collectiblesFound: Int { data.collectibles.reduce(0) { $0 + $1.count } }

    /// Busca (o crea) la subcategoría. Si no viene el grupo, usa el de la subcategoría que ya existe
    /// o, si el nombre es el de una categoría general (p. ej. "Kenton's Treasures"), esa misma.
    private func categoryIndex(_ d: inout PockitData, name cat: String, group: String?) -> Int {
        if let i = d.collectibles.firstIndex(where: { $0.name.caseInsensitiveCompare(cat) == .orderedSame }) {
            if let g = group?.trimmingCharacters(in: .whitespaces), !g.isEmpty { d.collectibles[i].group = g }
            return i
        }
        let g = group?.trimmingCharacters(in: .whitespaces).nilIfEmpty
            ?? CollectibleGroups.order.first { $0.caseInsensitiveCompare(cat) == .orderedSame }
            ?? "Otros"
        d.collectibles.append(CollectibleCategory(group: g, name: cat))
        return d.collectibles.count - 1
    }

    func addCollectible(category: String, item: String, total: Int?, group: String? = nil, variant: String? = nil, at date: Date = Date()) {
        let cat = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = item.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cat.isEmpty, !name.isEmpty else { return }
        mutate { d in
            let idx = categoryIndex(&d, name: cat, group: group)
            if let total, total > 0 { d.collectibles[idx].total = total }
            if let i = d.collectibles[idx].items.firstIndex(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                if let variant, !variant.isEmpty { d.collectibles[idx].items[i].variant = variant }
            } else {
                d.collectibles[idx].items.append(CollectibleItem(name: name, foundAt: date, variant: variant?.nilIfEmpty))
                // Si estaba contado "sin identificar", ahora que tiene nombre baja ese número.
                if d.collectibles[idx].extraCount > 0 { d.collectibles[idx].extraCount -= 1 }
            }
        }
    }

    /// Cuando el juego solo dice cuántos llevás (sin decir cuáles).
    func setCollectibleCount(category: String, count: Int, total: Int?, group: String? = nil) {
        let cat = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cat.isEmpty, count >= 0 else { return }
        mutate { d in
            let idx = categoryIndex(&d, name: cat, group: group)
            if let total, total > 0 { d.collectibles[idx].total = total }
            d.collectibles[idx].extraCount = max(0, count - d.collectibles[idx].items.count)
        }
    }

    /// Subcategoría desbloqueada pero vacía (como las de Waink Locations).
    func unlockCategory(_ name: String, group: String) {
        mutate { d in _ = categoryIndex(&d, name: name, group: group) }
    }

    var collectibleGroups: [(name: String, categories: [CollectibleCategory])] {
        let groups = Dictionary(grouping: data.collectibles, by: \.group)
        let ordered = CollectibleGroups.order.filter { groups[$0] != nil } + groups.keys.filter { !CollectibleGroups.order.contains($0) }.sorted()
        return ordered.map { ($0, groups[$0] ?? []) }
    }

    // MARK: BUCKME

    var buckmeTotal: Int { data.buckme.reduce(0) { $0 + $1.amount } }

    func setBuckme(name: String, amount: Int) {
        let clean = name.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else { return }
        mutate { d in
            if let i = d.buckme.firstIndex(where: { $0.name.caseInsensitiveCompare(clean) == .orderedSame }) {
                d.buckme[i].amount = amount
            } else {
                d.buckme.append(BuckmeAccount(name: clean, amount: amount))
            }
        }
        syncBuckmeTotal()
    }

    func saveBuckme(_ accounts: [BuckmeAccount]) {
        mutate { $0.buckme = accounts.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty } }
        syncBuckmeTotal()
    }

    /// El total de BUCKME en Money es la suma de sus cuentas.
    private func syncBuckmeTotal() {
        guard !data.buckme.isEmpty else { return }
        let sum = buckmeTotal
        let last = data.money.last
        if last?.app == sum { return }
        addMoney(MoneySnapshot(bank: last?.bank ?? 0, app: sum, home: last?.home ?? 0, source: "manual"))
    }

    func delete(_ item: CollectibleItem, in category: CollectibleCategory) {
        mutate { d in
            guard let i = d.collectibles.firstIndex(where: { $0.id == category.id }) else { return }
            d.collectibles[i].items.removeAll { $0.id == item.id }
        }
    }

    func setExtraCount(_ n: Int, in category: CollectibleCategory) {
        mutate { d in
            guard let i = d.collectibles.firstIndex(where: { $0.id == category.id }) else { return }
            d.collectibles[i].extraCount = max(0, n)
        }
    }

    func delete(category: CollectibleCategory) {
        mutate { $0.collectibles.removeAll { $0.id == category.id } }
    }

    // MARK: Misiones

    func logMission(_ name: String, pct: Int?, at date: Date = Date()) {
        if let last = data.missions.last, last.name.caseInsensitiveCompare(name) == .orderedSame {
            if let pct, last.pct != pct { mutate { $0.missions[$0.missions.count - 1].pct = pct } }
            return
        }
        mutate { $0.missions.append(MissionEntry(name: name, pct: pct, at: date)) }
    }

    // MARK: Mapa
    func savePin(_ p: MapPin) {
        mutate { d in
            if let i = d.pins.firstIndex(where: { $0.id == p.id }) { d.pins[i] = p } else { d.pins.append(p) }
        }
    }
    func delete(_ p: MapPin) { mutate { $0.pins.removeAll { $0.id == p.id } } }

    func delete(_ m: MissionEntry) { mutate { $0.missions.removeAll { $0.id == m.id } } }
}

extension String {
    var nilIfEmpty: String? { trimmingCharacters(in: .whitespaces).isEmpty ? nil : self }
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
