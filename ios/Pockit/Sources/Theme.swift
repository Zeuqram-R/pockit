import SwiftUI
import UIKit

enum Theme {
    // Morados del menú de GTA VI (sacados de fotos de la tele).
    static let night = Color(hex: 0x2B1E92)      // fondo base
    static let nightDeep = Color(hex: 0x1A1066)  // lo más oscuro
    static let panel = Color(hex: 0x3826A6)      // filas y paneles
    static let purple = Color(hex: 0x4A2DB8)     // chips y botones
    static let violet = Color(hex: 0x8248E3)     // brillo de arriba a la derecha
    static let line = Color.white.opacity(0.14)  // divisores
    /// Rosa de los switches, sliders y selección (con blanco), como en los ajustes del juego.
    static let switchPink = Color(hex: 0xCB84F8)
    static let pink = Color(hex: 0xFF3E8A)
    static let coral = Color(hex: 0xFF7A45)
    static let sunset = Color(hex: 0xFFB547)
    static let teal = Color(hex: 0x2EC4B6)
    static let cream = Color(hex: 0xFFF4E6)
    static let lilac = Color(hex: 0xE5D6F2)

    static let sky = LinearGradient(
        colors: [Color(hex: 0x4B1E6B), Color(hex: 0xB5307A), Color(hex: 0xFF5E6C), Color(hex: 0xFF9A4A), Color(hex: 0xFFC56B)],
        startPoint: .top, endPoint: .bottom)

    static let hot = LinearGradient(
        colors: [Color(hex: 0xFFC56B), coral, pink],
        startPoint: .top, endPoint: .bottom)

    /// Fondo de menú como el del juego: índigo abajo a la izquierda, violeta arriba a la derecha.
    static let menu = LinearGradient(
        colors: [Color(hex: 0x231783), Color(hex: 0x3E28AE), Color(hex: 0x4B2DBA), Color(hex: 0x8248E3)],
        startPoint: .bottomLeading, endPoint: .topTrailing)

    /// Títulos: Barlow Condensed (condensada en mayúsculas, como los menús de GTA VI).
    static func display(_ size: CGFloat, weight: DisplayWeight = .bold) -> Font {
        .custom(weight.rawValue, size: size, relativeTo: .title)
    }

    enum DisplayWeight: String {
        case semibold = "BarlowCondensed-SemiBold"
        case bold = "BarlowCondensed-Bold"
    }

    /// Texto: Figtree (sans geométrica, como el texto de los menús del juego).
    static func text(_ size: CGFloat, _ weight: TextWeight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(weight.rawValue, size: size, relativeTo: style)
    }

    enum TextWeight: String {
        case regular = "Figtree-Regular"
        case medium = "Figtree-Medium"
        case semibold = "Figtree-SemiBold"
    }

    /// Apariencia de UIKit (barra de navegación y control segmentado) con las letras y colores del juego.
    @MainActor static func applyUIKitAppearance() {
        // Arriba del todo (sin scroll) transparente; al bajar, barra morada con desenfoque
        // pa' que el contenido no quede encima de "Ajustes" y "Listo".
        let nav = UINavigationBarAppearance()
        nav.configureWithDefaultBackground()
        nav.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        nav.backgroundColor = UIColor(nightDeep).withAlphaComponent(0.9)
        nav.shadowColor = UIColor.white.withAlphaComponent(0.12)
        if let f = UIFont(name: DisplayWeight.bold.rawValue, size: 22) {
            nav.titleTextAttributes = [.font: f, .foregroundColor: UIColor.white]
        }
        if let f = UIFont(name: DisplayWeight.bold.rawValue, size: 36) {
            nav.largeTitleTextAttributes = [.font: f, .foregroundColor: UIColor.white]
        }
        if let f = UIFont(name: TextWeight.medium.rawValue, size: 17) {
            let button = UIBarButtonItemAppearance()
            button.normal.titleTextAttributes = [.font: f]
            nav.buttonAppearance = button
            nav.doneButtonAppearance = button
        }
        let edge = nav.copy()
        edge.configureWithTransparentBackground()
        edge.titleTextAttributes = nav.titleTextAttributes
        edge.largeTitleTextAttributes = nav.largeTitleTextAttributes
        edge.buttonAppearance = nav.buttonAppearance
        edge.doneButtonAppearance = nav.doneButtonAppearance
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = edge

        let seg = UISegmentedControl.appearance()
        seg.selectedSegmentTintColor = UIColor(switchPink)
        seg.backgroundColor = UIColor(nightDeep).withAlphaComponent(0.6)
        if let f = UIFont(name: TextWeight.semibold.rawValue, size: 14) {
            seg.setTitleTextAttributes([.font: f, .foregroundColor: UIColor.white], for: .normal)
            seg.setTitleTextAttributes([.font: f, .foregroundColor: UIColor.white], for: .selected)
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1)
    }
}

/// Título estilo menú de GTA VI: Barlow Condensed en mayúsculas, blanco, con sombra suave.
struct DisplayTitle: View {
    let text: String
    var size: CGFloat = 34

    var body: some View {
        Text(text.uppercased())
            .font(Theme.display(size))
            .foregroundStyle(.white)
            .shadow(color: Theme.nightDeep.opacity(0.5), radius: 0, x: 1, y: 1.5)
            .accessibilityLabel(text)
    }
}

/// Encabezado de sección como en los ajustes del juego (COMBAT, MOVEMENT…).
struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(Theme.display(17, weight: .semibold))
            .foregroundStyle(.white)
    }
}

extension View {
    /// Fila de formulario con el morado del menú del juego.
    func menuRow() -> some View {
        listRowBackground(Theme.panel.opacity(0.55))
            .listRowSeparatorTint(Theme.line)
    }
}
