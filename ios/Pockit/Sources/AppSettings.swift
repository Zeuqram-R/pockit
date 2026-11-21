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
    /// Nombre del ícono alternativo en el catálogo; nil = el principal.
    var alternateName: String? { self == .pin ? nil : "AppIconMarisol" }
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

    var currentIcon: AppIconChoice {
        UIApplication.shared.alternateIconName == nil ? .pin : .marisol
    }

    func setIcon(_ choice: AppIconChoice) {
        guard UIApplication.shared.supportsAlternateIcons,
              UIApplication.shared.alternateIconName != choice.alternateName else { return }
        UIApplication.shared.setAlternateIconName(choice.alternateName) { _ in
            Task { @MainActor in self.objectWillChange.send() }
        }
    }
}
