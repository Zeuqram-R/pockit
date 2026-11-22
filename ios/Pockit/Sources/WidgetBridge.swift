import Foundation
import WidgetKit

/// Le pasa al widget lo último (progreso, plata, pendientes, la cara de Marisol). Si el App Group no quedó
/// activo al firmar, simplemente no se escribe y el widget muestra "Abrí Pockit".
@MainActor
enum WidgetBridge {
    private static var last: Data?
    static func update(store: PockitStore, state: PockitState, lang: AppLanguage) {
        var s = WidgetSnapshot()
        s.pct = state.progressPct
        s.mission = state.progressMission
        s.money = store.currentMoney?.total
        s.pendientes = store.data.pendientes.filter { !$0.done }.suffix(3).reversed().map(\.text)
        s.collectibles = store.collectiblesFound
        s.mood = state.mood.rawValue
        s.lang = lang.rawValue
        let enc = JSONEncoder()
        var cmp = s; cmp.updatedAt = .distantPast
        let key = try? enc.encode(cmp)
        guard key != last else { return }
        last = key
        if s.save() { WidgetCenter.shared.reloadAllTimelines() }
    }
}
