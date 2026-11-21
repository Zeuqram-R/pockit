import SwiftUI

enum Theme {
    static let night = Color(hex: 0x1B1030)
    static let nightDeep = Color(hex: 0x0E0818)
    static let purple = Color(hex: 0x6B2D7B)
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

    /// Anton, la letra de títulos. Si no carga, cae en la del sistema.
    static func display(_ size: CGFloat) -> Font {
        .custom("Anton-Regular", size: size)
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

/// Título estilo Pockit: Anton inclinada, degradado sunset y contorno oscuro.
struct DisplayTitle: View {
    let text: String
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            Text(text).font(Theme.display(size)).foregroundStyle(Theme.nightDeep).offset(x: 1.5, y: 1.5)
            Text(text).font(Theme.display(size)).foregroundStyle(Theme.hot)
        }
        .transformEffect(CGAffineTransform(a: 1, b: 0, c: -0.12, d: 1, tx: 0, ty: 0))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}
