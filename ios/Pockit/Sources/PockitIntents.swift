import AppIntents
import Foundation

/// Buzón entre Siri/Atajos/notificaciones y la app: lo que llega aquí lo recoge RootView.
@MainActor
final class IntentInbox: ObservableObject {
    static let shared = IntentInbox()
    /// Mensaje pa' mandarle a Marisol en cuanto el chat esté listo.
    @Published var pendingMessage: String?
    /// Abrir la pestaña de Marisol (al tocar una notificación).
    @Published var openMarisol = false
}

private func lang() -> L10n { L10n.current }

// MARK: - Pregúntale a Marisol
struct AskMarisolIntent: AppIntent {
    static var title: LocalizedStringResource = "Pregúntale a Marisol"
    static var description = IntentDescription("Le manda una pregunta a Marisol en Pockit.")
    static var openAppWhenRun = true

    @Parameter(title: "Pregunta", requestValueDialog: IntentDialog("¿Qué le querés preguntar a Marisol?"))
    var question: String

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentInbox.shared.pendingMessage = question
        return .result()
    }
}

// MARK: - ¿Qué hago ahora?
struct WhatNowIntent: AppIntent {
    static var title: LocalizedStringResource = "¿Qué hago ahora?"
    static var description = IntentDescription("Le pregunta a Marisol qué hacer según tu progreso.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentInbox.shared.pendingMessage = lang().msgWhatNow
        return .result()
    }
}

// MARK: - ¿Dónde me quedé?
struct WhereWasIIntent: AppIntent {
    static var title: LocalizedStringResource = "¿Dónde me quedé?"
    static var description = IntentDescription("Marisol te recuerda en qué ibas.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentInbox.shared.pendingMessage = lang().s("¿Dónde me quedé? Dame un resumen corto de en qué iba, sin spoilers.",
                                                      "Where did I leave off? Give me a short recap, no spoilers.")
        return .result()
    }
}

// MARK: - Mi progreso (sin abrir la app)
struct MyProgressIntent: AppIntent {
    static var title: LocalizedStringResource = "Mi progreso en GTA VI"
    static var description = IntentDescription("Te dice tu porcentaje, la última misión y tu plata.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let t = lang()
        let d = UserDefaults.standard
        let pct = d.object(forKey: "pockit.progress.pct") as? Int ?? -1
        let mission = d.string(forKey: "pockit.progress.mission") ?? ""
        var parts: [String] = []
        if pct >= 0 { parts.append(t.s("Vas en \(pct)%", "You're at \(pct)%")) }
        if !mission.isEmpty { parts.append(t.s("la última misión fue \(mission)", "last mission was \(mission)")) }
        if let total = Self.moneyTotal() { parts.append(t.s("y tenés \(Fmt.money(total))", "and you have \(Fmt.money(total))")) }
        let text = parts.isEmpty ? t.s("Todavía no me has contado tu progreso.", "You haven't told me your progress yet.")
                                 : parts.joined(separator: ", ") + "."
        return .result(dialog: IntentDialog(stringLiteral: text))
    }

    /// Lee la plata del archivo de Pockit sin cargar toda la app.
    static func moneyTotal() -> Int? {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("pockit-data.json")
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        guard let raw = try? Data(contentsOf: url), let data = try? dec.decode(PockitData.self, from: raw), let last = data.money.last else { return nil }
        return last.total
    }
}

// MARK: - Frases de Siri
struct PockitShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: AskMarisolIntent(), phrases: [
            "Pregúntale a Marisol en \(.applicationName)",
            "Pregunta a Marisol en \(.applicationName)",
            "Ask Marisol in \(.applicationName)"
        ], shortTitle: "Pregúntale a Marisol", systemImageName: "bubble.left.and.text.bubble.right.fill")
        AppShortcut(intent: WhatNowIntent(), phrases: [
            "Qué hago ahora en \(.applicationName)",
            "What should I do now in \(.applicationName)"
        ], shortTitle: "¿Qué hago ahora?", systemImageName: "location.north.circle.fill")
        AppShortcut(intent: WhereWasIIntent(), phrases: [
            "Dónde me quedé en \(.applicationName)",
            "Where did I leave off in \(.applicationName)"
        ], shortTitle: "¿Dónde me quedé?", systemImageName: "arrow.uturn.backward.circle.fill")
        AppShortcut(intent: MyProgressIntent(), phrases: [
            "Mi progreso en \(.applicationName)",
            "Cómo voy en \(.applicationName)",
            "My progress in \(.applicationName)"
        ], shortTitle: "Mi progreso", systemImageName: "chart.bar.fill")
    }
}
