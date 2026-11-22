import SwiftUI

/// Ícono de una sección: uno de nuestros íconos (en el estilo elegido) o un símbolo mientras se diseña el suyo.
enum SegIcon {
    case tab(PockitTab)
    case symbol(String)
}

/// Selector de secciones con el ícono arriba de la palabra (Progress y Portfolio).
struct IconSegments<T: Hashable>: View {
    let items: [(value: T, title: String, icon: SegIcon)]
    @Binding var selection: T
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items, id: \.value) { item in
                let active = selection == item.value
                Button {
                    if !active { UISelectionFeedbackGenerator().selectionChanged() }
                    withAnimation(.easeOut(duration: 0.2)) { selection = item.value }
                } label: {
                    VStack(spacing: 4) {
                        icon(item.icon, active: active).frame(width: 34, height: 34)
                        Text(item.title)
                            .font(Theme.text(12, active ? .semibold : .regular, relativeTo: .caption))
                            .foregroundStyle(active ? Theme.switchPink : Theme.lilac)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(active ? Theme.switchPink.opacity(0.16) : Color.clear))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(active ? Theme.switchPink.opacity(0.55) : Color.clear, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.nightDeep.opacity(0.55)))
    }

    @ViewBuilder private func icon(_ i: SegIcon, active: Bool) -> some View {
        switch i {
        case .tab(let tab):
            TabItemView(tab: tab, active: active, style: settings.tabIconStyle, title: "")
                .frame(width: 40, height: 40)
                .scaleEffect(0.85)
                .clipped()
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(active ? Theme.switchPink : .white.opacity(0.85))
        }
    }
}

/// Barra de navegación que se difumina poco a poco al hacer scroll (en vez de aparecer de golpe).
struct FadingNavBar: ViewModifier {
    @State private var progress: CGFloat = 0

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .onScrollGeometryChange(for: CGFloat.self) { g in
                    g.contentOffset.y + g.contentInsets.top
                } action: { _, y in
                    progress = min(max(y / 70, 0), 1)
                }
                .toolbarBackground(Theme.nightDeep.opacity(0.88 * progress), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        } else {
            content
        }
    }
}

extension View {
    func fadingNavBar() -> some View { modifier(FadingNavBar()) }
}
