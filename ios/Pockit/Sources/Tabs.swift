import SwiftUI
import UIKit

enum PockitTab: String, CaseIterable, Identifiable {
    case marisol, pendientes, money, collectibles, mapa
    var id: String { rawValue }

    func title(_ t: L10n) -> String {
        switch self {
        case .marisol: return "Marisol"
        case .pendientes: return t.s("Pendientes", "To-do")
        case .money: return "Portfolio"
        case .collectibles: return "Progress"
        case .mapa: return t.s("Mapa", "Map")
        }
    }
}

/// Los dos juegos de íconos de la barra. Se cambian en Ajustes, como el ícono de la app.
enum TabIconStyle: String, CaseIterable, Identifiable {
    case color, game
    var id: String { rawValue }
    func title(_ t: L10n) -> String { self == .color ? t.s("A color", "Full color") : t.s("Estilo del juego", "Game style") }
}

/// Barra de pestañas de vidrio con bordes curvos.
struct PockitTabBar: View {
    @Binding var selection: PockitTab
    let style: TabIconStyle
    let t: L10n

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PockitTab.allCases) { tab in
                Button {
                    if selection != tab { UISelectionFeedbackGenerator().selectionChanged() }
                    selection = tab
                } label: {
                    TabItemView(tab: tab, active: selection == tab, style: style, title: tab.title(t))
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title(t))
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .frame(height: 66)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(Capsule(style: .continuous).fill(Theme.nightDeep.opacity(0.55)))
                .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.22), lineWidth: 1))
                .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
        }
        .frame(maxWidth: 520)
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }
}

struct TabItemView: View {
    let tab: PockitTab
    let active: Bool
    let style: TabIconStyle
    let title: String

    var body: some View {
        VStack(spacing: 3) {
            icon.frame(width: 40, height: 40)
            Text(title)
                .font(Theme.text(11, active ? .semibold : .regular, relativeTo: .caption2))
                .foregroundStyle(active ? Theme.switchPink : Theme.lilac)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .animation(.easeOut(duration: 0.18), value: active)
    }

    @ViewBuilder private var icon: some View {
        if style == .color || tab == .marisol {
            Image(active ? "TabColor_\(tab.rawValue)" : "TabOff_\(tab.rawValue)")
                .resizable()
                .scaledToFit()
                .frame(width: active ? 38 : 33, height: active ? 38 : 33)
                .opacity(active ? 1 : 0.85)
        } else if active {
            ActiveGlyphTile(imageName: "TabGlyphDark_\(tab.rawValue)", side: 38)
        } else {
            Image("TabGlyph_\(tab.rawValue)")
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)
                .opacity(0.9)
        }
    }
}

/// Cuadrito blanco del estilo del juego: sólido arriba, se difumina abajo, raya rosa al pie.
struct ActiveGlyphTile: View {
    let imageName: String
    var side: CGFloat = 38

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: side * 0.24, style: .continuous)
                .fill(LinearGradient(stops: [
                    .init(color: Color(hex: 0xF5F3F8), location: 0),
                    .init(color: Color(hex: 0xF5F3F8), location: 0.58),
                    .init(color: Color(hex: 0xF5F3F8).opacity(0), location: 0.90),
                ], startPoint: .top, endPoint: .bottom))
            Rectangle()
                .fill(Theme.switchPink)
                .frame(height: 3)
                .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: side * 0.24, bottomTrailingRadius: side * 0.24, style: .continuous))
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: side * 0.68, height: side * 0.68)
                .frame(maxHeight: .infinity)
        }
        .frame(width: side, height: side)
    }
}

/// Muestra de cada juego de íconos pa' el selector de Ajustes.
struct TabStylePreview: View {
    let style: TabIconStyle

    var body: some View {
        HStack(spacing: 8) {
            TabItemIconOnly(tab: .money, active: true, style: style)
            TabItemIconOnly(tab: .collectibles, active: false, style: style)
            TabItemIconOnly(tab: .mapa, active: false, style: style)
        }
        .padding(.horizontal, 10)
        .frame(height: 58)
        .background(Capsule().fill(Theme.nightDeep.opacity(0.7)))
        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
    }
}

private struct TabItemIconOnly: View {
    let tab: PockitTab
    let active: Bool
    let style: TabIconStyle
    var body: some View {
        TabItemView(tab: tab, active: active, style: style, title: "").frame(width: 40, height: 44).clipped()
    }
}

/// Avisa cuando el teclado está abierto (la barra se esconde pa' no tapar el chat).
@MainActor
final class KeyboardWatcher: ObservableObject {
    @Published var visible = false
    private var tokens: [NSObjectProtocol] = []

    init() {
        let nc = NotificationCenter.default
        tokens.append(nc.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.visible = true }
        })
        tokens.append(nc.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.visible = false }
        })
    }

    deinit { for token in tokens { NotificationCenter.default.removeObserver(token) } }
}
