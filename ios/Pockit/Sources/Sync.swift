import Foundation
import Security
import UIKit

/// Guarda el token de GitHub solo en el Keychain del dispositivo (nunca en el código ni en el repo).
enum Keychain {
    private static let service = "com.zeuqram.pockit.github"
    static func get() -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }
    static func set(_ token: String?) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
        SecItemDelete(base as CFDictionary)
        guard let token, !token.isEmpty else { return }
        var add = base
        add[kSecValueData as String] = Data(token.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }
}

/// Lo que se sube a pockit-datos: el tracker completo + el progreso.
private struct SyncFile: Codable {
    var data: PockitData
    var progressPct: Int
    var progressMission: String
    var device: String
    var savedAt: Date
}

/// Sincroniza el tracker (dinero, coleccionables, pendientes, pines del mapa, lugares…) entre iPhone, iPad y Mac
/// usando el repo privado Zeuqram-R/pockit-datos. Baja al abrir la app y sube unos segundos después de cada cambio.
/// Si dos dispositivos cambiaron cosas a la vez, se juntan las listas (no se pierde nada).
@MainActor
final class SyncManager: ObservableObject {
    static let shared = SyncManager()
    static let repo = "Zeuqram-R/pockit-datos"
    static let path = "pockit/data.json"

    enum Status: Equatable { case off, idle, syncing, ok(Date), error(String) }
    @Published var status: Status = .off
    @Published var hasToken = Keychain.get() != nil

    private weak var store: PockitStore?
    private weak var state: PockitState?
    private var pushTask: Task<Void, Never>?
    private var applyingRemote = false
    private let lastKey = "pockit.sync.lastRemoteAt"
    private var lastRemoteAt: Date? {
        get { UserDefaults.standard.object(forKey: lastKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastKey) }
    }

    func attach(store: PockitStore, state: PockitState) {
        self.store = store
        self.state = state
        store.onLocalChange = { [weak self] in self?.schedulePush() }
        status = hasToken ? .idle : .off
    }

    func setToken(_ token: String?) {
        Keychain.set(token?.trimmingCharacters(in: .whitespacesAndNewlines))
        hasToken = Keychain.get() != nil
        status = hasToken ? .idle : .off
        if hasToken { Task { await sync() } }
    }

    private func schedulePush() {
        guard hasToken, !applyingRemote else { return }
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            await self?.sync()
        }
    }

    // MARK: GitHub
    private func request(_ method: String, body: Data? = nil) -> URLRequest? {
        guard let token = Keychain.get(),
              let url = URL(string: "https://api.github.com/repos/\(Self.repo)/contents/\(Self.path)") else { return nil }
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        r.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        r.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        r.cachePolicy = .reloadIgnoringLocalCacheData
        if let body { r.httpBody = body; r.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        return r
    }

    private func fetchRemote() async throws -> (SyncFile?, String?) {
        guard let req = request("GET") else { throw SyncError.noToken }
        let (d, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 404 { return (nil, nil) }
        if code == 401 || code == 403 { throw SyncError.auth }
        guard code == 200, let o = try JSONSerialization.jsonObject(with: d) as? [String: Any],
              let b64 = o["content"] as? String, let sha = o["sha"] as? String,
              let raw = Data(base64Encoded: b64.replacingOccurrences(of: "\n", with: "")) else { throw SyncError.bad(code) }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        let file = try? dec.decode(SyncFile.self, from: raw)
        return (file, sha)
    }

    private func putRemote(_ file: SyncFile, sha: String?) async throws {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601; enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        let raw = try enc.encode(file)
        var body: [String: Any] = ["message": "Pockit: \(file.device) · \(ISO8601DateFormatter().string(from: Date()))",
                                   "content": raw.base64EncodedString()]
        if let sha { body["sha"] = sha }
        guard let req = request("PUT", body: try JSONSerialization.data(withJSONObject: body)) else { throw SyncError.noToken }
        let (_, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 409 || code == 422 { throw SyncError.conflict }
        if code == 401 || code == 403 { throw SyncError.auth }
        guard code == 200 || code == 201 else { throw SyncError.bad(code) }
    }

    enum SyncError: Error { case noToken, auth, conflict, bad(Int) }

    // MARK: Sincronizar
    func sync(retry: Bool = true) async {
        guard hasToken, let store, let state else { return }
        if case .syncing = status { return }
        status = .syncing
        do {
            let (remote, sha) = try await fetchRemote()
            let local = store.data
            let localChanged = lastRemoteAt.map { local.updatedAt > $0.addingTimeInterval(0.5) } ?? true

            if let remote, remote.data.updatedAt > (lastRemoteAt ?? .distantPast).addingTimeInterval(0.5) {
                // Hay algo nuevo en otro dispositivo
                applyingRemote = true
                if localChanged {
                    var merged = Self.merge(local: local, remote: remote.data).deduped()
                    merged.updatedAt = Date()
                    store.replaceFromSync(merged)
                } else {
                    store.replaceFromSync(remote.data.deduped())
                }
                if remote.progressPct >= 0, remote.data.updatedAt >= local.updatedAt {
                    state.progressPct = remote.progressPct
                    if !remote.progressMission.isEmpty { state.progressMission = remote.progressMission }
                }
                applyingRemote = false
                lastRemoteAt = remote.data.updatedAt
                if localChanged { try await upload(store: store, state: state, sha: sha) }
            } else if localChanged || remote == nil {
                try await upload(store: store, state: state, sha: sha)
            }
            status = .ok(Date())
        } catch SyncError.conflict where retry {
            status = .idle
            await sync(retry: false)
        } catch SyncError.auth {
            status = .error(L10n.current.s("El token no sirve o no tiene acceso a pockit-datos.", "The token is invalid or can't reach pockit-datos."))
        } catch {
            status = .error(L10n.current.s("Sin conexión. Lo intento después.", "Offline. Will retry later."))
        }
    }

    private func upload(store: PockitStore, state: PockitState, sha: String?) async throws {
        let file = SyncFile(data: store.data, progressPct: state.progressPct, progressMission: state.progressMission,
                            device: UIDevice.current.model, savedAt: Date())
        try await putRemote(file, sha: sha)
        lastRemoteAt = store.data.updatedAt
    }

    /// Junta dos versiones: las listas se unen por id (si están en ambas, gana la más reciente del otro lado),
    /// los valores sueltos se quedan con los del otro dispositivo.
    static func merge(local: PockitData, remote: PockitData) -> PockitData {
        func u<T: Identifiable>(_ a: [T], _ b: [T]) -> [T] {
            var out = b
            let ids = Set(b.map(\.id))
            for x in a where !ids.contains(x.id) { out.append(x) }
            return out
        }
        func us(_ a: [String], _ b: [String]) -> [String] {
            var out = b
            for x in a where !out.contains(where: { $0.caseInsensitiveCompare(x) == .orderedSame }) { out.append(x) }
            return out
        }
        var m = remote
        m.pendientes = u(local.pendientes, remote.pendientes)
        m.libreta = u(local.libreta, remote.libreta)
        m.money = u(local.money, remote.money).sorted { $0.at < $1.at }
        m.propiedades = u(local.propiedades, remote.propiedades)
        m.missions = u(local.missions, remote.missions).sorted { $0.at < $1.at }
        m.vehicles = u(local.vehicles, remote.vehicles)
        m.buckme = u(local.buckme, remote.buckme)
        m.pins = u(local.pins, remote.pins)
        m.places = us(local.places, remote.places)
        m.placeCats = us(local.placeCats, remote.placeCats)
        // Coleccionables: por categoría, se juntan los ítems encontrados
        var cats = remote.collectibles
        for lc in local.collectibles {
            if let i = cats.firstIndex(where: { $0.name == lc.name }) {
                for it in lc.items where !cats[i].items.contains(where: { $0.name.caseInsensitiveCompare(it.name) == .orderedSame && $0.variant == it.variant }) { cats[i].items.append(it) }
                cats[i].extraCount = max(cats[i].extraCount, lc.extraCount)
            } else { cats.append(lc) }
        }
        m.collectibles = cats
        return m
    }
}

// MARK: - Limpieza de duplicados
// Cada dispositivo lee las mismas respuestas de Marisol, así que al juntar los datos pueden quedar
// cosas repetidas (ej. "Checking Account" dos veces). Esto las une.
extension PockitData {
    func deduped() -> PockitData {
        var d = self
        func key(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        func uniq<T>(_ a: [T], by k: (T) -> String, prefer: (T, T) -> Bool = { _, _ in false }) -> [T] {
            var out: [T] = []; var idx: [String: Int] = [:]
            for x in a {
                let kk = k(x)
                if let i = idx[kk] { if prefer(x, out[i]) { out[i] = x } } else { idx[kk] = out.count; out.append(x) }
            }
            return out
        }
        d.buckme = uniq(d.buckme, by: { key($0.name) })
        d.pendientes = uniq(d.pendientes, by: { key($0.text) }, prefer: { new, old in new.done && !old.done })
        d.libreta = uniq(d.libreta, by: { key($0.text) })
        d.propiedades = uniq(d.propiedades, by: { key($0.name) })
        d.vehicles = uniq(d.vehicles, by: { key($0.name) + "|" + key($0.location) })
        d.missions = uniq(d.missions, by: { key($0.name) })
        // Plata: la misma foto (mismos montos) repetida en menos de 30 min cuenta una sola vez
        var money: [MoneySnapshot] = []
        for s in d.money.sorted(by: { $0.at < $1.at }) {
            if let last = money.last, last.bank == s.bank, last.app == s.app, last.home == s.home,
               s.at.timeIntervalSince(last.at) < 1800 { continue }
            money.append(s)
        }
        d.money = money
        d.collectibles = d.collectibles.map { c in
            var c = c
            c.items = uniq(c.items, by: { key($0.name) + "|" + key($0.variant ?? "") })
            return c
        }
        return d
    }
}
