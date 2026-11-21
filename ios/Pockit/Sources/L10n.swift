import Foundation

/// Todos los textos de la app en español y en inglés.
struct L10n {
    let lang: AppLanguage
    init(_ lang: AppLanguage) { self.lang = lang }

    private func s(_ es: String, _ en: String) -> String { lang == .es ? es : en }

    // Pantalla de carga
    var loading: String { s("Marisol se está arreglando…", "Marisol is getting ready…") }
    var loadFailed: String { s("No pude abrir claude.ai. Revisá tu internet.", "Couldn't open claude.ai. Check your connection.") }
    var retry: String { s("Reintentar", "Try again") }

    // Ajustes
    var settings: String { s("Ajustes", "Settings") }
    var done: String { s("Listo", "Done") }
    var language: String { s("Idioma", "Language") }
    var languageFooter: String { s("Cambia los textos de Pockit.", "Changes Pockit's text.") }
    var icon: String { s("Ícono", "App icon") }
    var iconPin: String { s("Pin de Leonida", "Leonida pin") }
    var iconMarisol: String { s("Silueta de Marisol", "Marisol silhouette") }
    var session: String { s("Sesión de claude.ai", "claude.ai session") }
    var pasteLink: String { s("Pegar link de acceso", "Paste sign-in link") }
    var pasteLinkFooter: String {
        s("Si el correo de acceso de Claude se abre en Safari, mantené presionado el link en el correo, copialo y tocá aquí.",
          "If Claude's sign-in email opens in Safari, long-press the link in the email, copy it and tap here.")
    }
    var pasteLinkInvalid: String { s("Lo que copiaste no es un link de claude.ai.", "What you copied isn't a claude.ai link.") }
    var reload: String { s("Recargar", "Reload") }
    var goHome: String { s("Volver al Project GTA VI", "Back to the GTA VI Project") }
    var signOut: String { s("Borrar sesión", "Clear session") }
    var signOutConfirm: String { s("¿Borrar la sesión de claude.ai en Pockit? Vas a tener que entrar de nuevo.", "Clear the claude.ai session in Pockit? You'll need to sign in again.") }
    var cancel: String { s("Cancelar", "Cancel") }
    var about: String { s("Acerca de", "About") }
    var version: String { s("Versión", "Version") }
}
