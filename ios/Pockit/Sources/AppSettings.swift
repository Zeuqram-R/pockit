import SwiftUI
import UIKit

enum AppLanguage: String, CaseIterable, Identifiable {
    case es, en
    var id: String { rawValue }
    var label: String { self == .es ? "Español" : "English" }
}

enum AppIconChoice: String, CaseIterable, Identifiable {
    case pin, marisol
    var id: String { rawValue }
    /// Los dos se ponen como íconos alternativos (el pin también tiene su copia "AppIconPin"),
    /// así nunca dependemos de volver al principal con `nil`, que falla en apps re-firmadas.
    var alternateName: String { self == .pin ? "AppIconPin" : "AppIconMarisol" }
    var preview: String { self == .pin ? "IconPreviewPin" : "IconPreviewMarisol" }
}

@MainActor
final class AppSettings: ObservableObject {
    @AppStorage("pockit.lang") var languageRaw: String = AppLanguage.es.rawValue {
        didSet { objectWillChange.send() }
    }

    var language: AppLanguage {
        get { AppLanguage(rawValue: languageRaw) ?? .es }
        set { languageRaw = newValue.rawValue }
    }

    var t: L10n { L10n(language) }

    /// El ícono escogido lo guardamos nosotros: con apps re-firmadas, iOS a veces devuelve
    /// `alternateIconName == nil` aunque el ícono sí cambió, y eso bloqueaba volver al pin.
    @AppStorage("pockit.icon") private var iconRaw: String = AppIconChoice.pin.rawValue

    @Published var iconError: String?

    var currentIcon: AppIconChoice { AppIconChoice(rawValue: iconRaw) ?? .pin }

    func setIcon(_ choice: AppIconChoice) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let previous = iconRaw
        iconRaw = choice.rawValue
        objectWillChange.send()
        UIApplication.shared.setAlternateIconName(choice.alternateName) { error in
            Task { @MainActor in
                guard let error else { return }
                let ns = error as NSError
                // "Ya es ese ícono" no es un error real: dejamos la selección como está.
                if ns.localizedDescription.lowercased().contains("already") { return }
                self.iconRaw = previous
                self.iconError = ns.localizedDescription
                self.objectWillChange.send()
            }
        }
    }
}
