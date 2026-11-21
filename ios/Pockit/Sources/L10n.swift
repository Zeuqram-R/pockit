import Foundation

/// Todos los textos de la app en español y en inglés.
struct L10n {
    let lang: AppLanguage
    init(_ lang: AppLanguage) { self.lang = lang }

    func s(_ es: String, _ en: String) -> String { lang == .es ? es : en }

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
    var iconFooter: String { s("iOS te avisa con un cuadro cada vez que cambia el ícono.", "iOS shows a notice every time the icon changes.") }
    var iconFailed: String { s("No pude cambiar el ícono", "Couldn't change the icon") }
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
    var send: String { s("Enviar", "Send") }

    // Botones rápidos
    var qProgress: String { s("Progreso", "Progress") }
    var qWhatNow: String { s("¿Qué hago ahora?", "What now?") }
    var qHint: String { s("Otra pista", "Another hint") }
    var qTellMe: String { s("Dime ya", "Full answer") }
    var msgWhatNow: String { s("¿Qué hago ahora?", "What should I do now?") }
    var msgHint: String { s("Otra pista", "Another hint, please") }
    var msgTellMe: String { s("Dime ya", "Full answer") }
    var sendFailed: String { s("No pude escribir en el chat. Abrí un chat y probá otra vez.", "Couldn't type in the chat. Open a chat and try again.") }

    // Progreso
    var noProgressYet: String { s("Mandá tu 📍 Progreso", "Send your 📍 Progress") }
    var progressPct: String { s("Porcentaje del juego", "Game completion") }
    var progressMission: String { s("Última misión", "Last mission") }
    var progressMissionPlaceholder: String { s("Ej. Island Dreams", "e.g. Island Dreams") }

    // Spoilers
    var spoilersOn: String { s("Spoilers ON", "Spoilers ON") }
    var spoilersOff: String { s("Sin spoilers", "No spoilers") }
    var spoilersTurnOnQ: String { s("¿Activar spoilers? Marisol te va a poder contar cosas de más adelante.", "Turn spoilers on? Marisol will be able to tell you things from later in the game.") }
    var spoilersTurnOffQ: String { s("¿Desactivar spoilers?", "Turn spoilers off?") }
    var spoilersTurnOn: String { s("Activar spoilers", "Turn spoilers on") }
    var spoilersTurnOff: String { s("Desactivar spoilers", "Turn spoilers off") }

    // Skin
    var skin: String { s("Colores del chat", "Chat colors") }
    var skinToggle: String { s("Skin de Pockit", "Pockit skin") }
    var skinFooter: String { s("Apagalo si el chat se ve raro (modo seguro). Los colores se descargan de tu repo pockit-skin.", "Turn it off if the chat looks off (safe mode). Colors come from your pockit-skin repo.") }
    var skinRemoteOff: String { s("Apagado desde config.json en GitHub.", "Turned off from config.json on GitHub.") }
    var skinStatus: String { s("Estado", "Status") }
    var diagnose: String { s("Diagnóstico del skin", "Skin diagnostics") }
    var diagnoseCopied: String { s("Copiado. Pegáselo a Claude pa' ajustar los colores.", "Copied. Paste it to Claude to tune the colors.") }
    var about: String { s("Acerca de", "About") }
    var version: String { s("Versión", "Version") }
}
